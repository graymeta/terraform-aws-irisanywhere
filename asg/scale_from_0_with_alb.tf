resource "aws_sns_topic" "scale_from_zero" {
  count = !var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-scale-from-zero", ".", "")
  tags  = local.merged_tags
}

data "archive_file" "scale_from_zero_zip" {
  count       = !var.haproxy ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/scale_from_zero.zip"

  source {
    content  = <<EOF
import boto3
import os
import time

STARTING_UP_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="30">
  <title>Service Starting...</title>
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #1a1a2e; color: #eee; }
    .box { text-align: center; }
    .spinner { width: 50px; height: 50px; border: 5px solid #333; border-top-color: #4CAF50; border-radius: 50%; animation: spin 1s linear infinite; margin: 20px auto; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="box">
    <div class="spinner"></div>
    <h2>Service Starting</h2>
    <p>This page will refresh automatically in 30 seconds.</p>
  </div>
</body>
</html>"""

def handler(event, context):
    asg_name           = os.environ['ASG_NAME']
    listener_rule_arn  = os.environ['LISTENER_RULE_ARN']
    listener_arn       = os.environ['LISTENER_ARN']
    target_group_arn   = os.environ['TARGET_GROUP_ARN']

    autoscaling = boto3.client('autoscaling')
    elbv2       = boto3.client('elbv2')

    asg = autoscaling.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_name]
    )['AutoScalingGroups'][0]

    if asg['DesiredCapacity'] > 0:
        print(f"ASG already has {asg['DesiredCapacity']} instance(s) — nothing to do.")
        return {'statusCode': 200, 'body': 'Already running'}

    # Save original actions so we can restore them
    original_rule_actions = elbv2.describe_rules(
        RuleArns=[listener_rule_arn]
    )['Rules'][0]['Actions']

    original_listener_actions = elbv2.describe_listeners(
        ListenerArns=[listener_arn]
    )['Listeners'][0]['DefaultActions']

    starting_up_action = [{
        'Type': 'fixed-response',
        'FixedResponseConfig': {
            'StatusCode': '503',
            'ContentType': 'text/html',
            'MessageBody': STARTING_UP_HTML,
        }
    }]

    try:
        print("Switching ALB to 'starting up' page")
        elbv2.modify_rule(RuleArn=listener_rule_arn, Actions=starting_up_action)
        elbv2.modify_listener(ListenerArn=listener_arn, DefaultActions=starting_up_action)

        print("Scaling ASG to 1")
        autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            DesiredCapacity=1
        )

        print("Waiting for a healthy target...")
        for i in range(60):
            time.sleep(5)
            health = elbv2.describe_target_health(TargetGroupArn=target_group_arn)
            healthy = [t for t in health['TargetHealthDescriptions']
                       if t['TargetHealth']['State'] == 'healthy']
            if healthy:
                print(f"Target healthy after {(i + 1) * 5}s")
                break
        else:
            print("Timed out waiting for healthy target — restoring ALB anyway")

    finally:
        print("Restoring original ALB actions")
        elbv2.modify_rule(RuleArn=listener_rule_arn, Actions=original_rule_actions)
        elbv2.modify_listener(ListenerArn=listener_arn, DefaultActions=original_listener_actions)

    return {'statusCode': 200, 'body': 'Scaled to 1 and ALB restored'}
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "scale_from_zero" {
  count         = !var.haproxy ? 1 : 0
  filename      = data.archive_file.scale_from_zero_zip[0].output_path
  function_name = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-scale-from-zero", ".", "")
  role          = aws_iam_role.scale_from_zero[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 360

  source_code_hash = data.archive_file.scale_from_zero_zip[0].output_base64sha256

  environment {
    variables = {
      ASG_NAME          = aws_autoscaling_group.iris.name
      LISTENER_RULE_ARN = aws_lb_listener_rule.port443[0].arn
      LISTENER_ARN      = aws_lb_listener.port443[0].arn
      TARGET_GROUP_ARN  = aws_lb_target_group.port443[0].arn
    }
  }

  tags = local.merged_tags
}

resource "aws_lambda_permission" "scale_from_zero_sns" {
  count         = !var.haproxy ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_from_zero[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.scale_from_zero[0].arn
}

resource "aws_sns_topic_subscription" "scale_from_zero" {
  count     = !var.haproxy ? 1 : 0
  topic_arn = aws_sns_topic.scale_from_zero[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.scale_from_zero[0].arn
}

resource "aws_iam_role" "scale_from_zero" {
  count = !var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-scale-from-zero-role", ".", "")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.merged_tags
}

resource "aws_iam_role_policy" "scale_from_zero" {
  count = !var.haproxy ? 1 : 0
  name  = "scale-from-zero-policy"
  role  = aws_iam_role.scale_from_zero[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      }
    ]
  })
}
