# ---- HANDLER LAMBDA (ALB target — responds instantly with "starting up" page) ----

data "archive_file" "scale_from_zero_handler_zip" {
  count       = !var.haproxy ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/scale_from_zero_handler.zip"

  source {
    content  = <<EOF
import boto3, json, os

STARTING_UP_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="5">
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
    <h2>Iris Anywhere server is starting.</h2>
    <p>It will take around 2 minutes to start. You will be redirected once it loads.</p>
    <p>If it has been longer than 10 minutes, contact your Iris Administrator.</p>
  </div>
</body>
</html>"""

READY_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="2">
  <title>Ready</title>
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #1a1a2e; color: #eee; }
  </style>
</head>
<body><p>Service ready, connecting...</p></body>
</html>"""

def handler(event, context):
    asg_name        = os.environ['ASG_NAME']
    worker_arn      = os.environ['WORKER_LAMBDA_ARN']
    rule_arn        = os.environ['LISTENER_RULE_ARN']
    ec2_tg_arn      = os.environ['EC2_TARGET_GROUP_ARN']

    elbv2       = boto3.client('elbv2')
    autoscaling = boto3.client('autoscaling')

    # If EC2 is already healthy, switch the rule immediately and send user through
    health = elbv2.describe_target_health(TargetGroupArn=ec2_tg_arn)
    healthy = [t for t in health['TargetHealthDescriptions'] if t['TargetHealth']['State'] == 'healthy']
    if healthy:
        print("EC2 already healthy — switching rule to EC2 TG immediately")
        elbv2.modify_rule(
            RuleArn=rule_arn,
            Actions=[{'Type': 'forward', 'TargetGroupArn': ec2_tg_arn}]
        )
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html'},
            'body': READY_HTML,
            'isBase64Encoded': False
        }

    # No healthy EC2 targets — scale up if needed and fire worker once
    asg = autoscaling.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_name]
    )['AutoScalingGroups'][0]

    if asg['DesiredCapacity'] == 0:
        print("ASG at 0 — setting fast health check and scaling to 1")
        elbv2.modify_target_group(
            TargetGroupArn=ec2_tg_arn,
            HealthCheckIntervalSeconds=5,
            HealthCheckTimeoutSeconds=3
        )
        autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            DesiredCapacity=1
        )
        boto3.client('lambda').invoke(
            FunctionName=worker_arn,
            InvocationType='Event',
            Payload=json.dumps({'action': 'wait_and_switch_to_ec2'})
        )
    else:
        print(f"ASG desired={asg['DesiredCapacity']} but no healthy targets yet — worker already running")

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'text/html'},
        'body': STARTING_UP_HTML,
        'isBase64Encoded': False
    }
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "scale_from_zero_handler" {
  count         = !var.haproxy ? 1 : 0
  filename      = data.archive_file.scale_from_zero_handler_zip[0].output_path
  function_name = substr(replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-sfz-handler", ".", ""), 0, 64)
  role          = aws_iam_role.scale_from_zero[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 10

  source_code_hash = data.archive_file.scale_from_zero_handler_zip[0].output_base64sha256

  environment {
    variables = {
      ASG_NAME            = aws_autoscaling_group.iris.name
      WORKER_LAMBDA_ARN   = aws_lambda_function.scale_from_zero_worker[0].arn
      LISTENER_RULE_ARN   = aws_lb_listener_rule.port443[0].arn
      EC2_TARGET_GROUP_ARN = aws_lb_target_group.port443[0].arn
    }
  }

  tags = local.merged_tags
}

# ---- WORKER LAMBDA (async — polls for healthy EC2, switches ALB rule) ----

data "archive_file" "scale_from_zero_worker_zip" {
  count       = !var.haproxy ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/scale_from_zero_worker.zip"

  source {
    content  = <<EOF
import boto3, json, os, time

def handler(event, context):
    rule_arn        = os.environ['LISTENER_RULE_ARN']
    ec2_tg_arn      = os.environ['EC2_TARGET_GROUP_ARN']
    lambda_tg_arn   = os.environ['LAMBDA_TARGET_GROUP_ARN']

    # ASG termination notification — only switch to Lambda TG if desired is now 0
    if 'Records' in event:
        asg = boto3.client('autoscaling').describe_auto_scaling_groups(
            AutoScalingGroupNames=[os.environ['ASG_NAME']]
        )['AutoScalingGroups'][0]
        in_service = sum(1 for i in asg['Instances'] if i['LifecycleState'] == 'InService')
        if asg['DesiredCapacity'] == 0 and in_service == 0:
            print("ASG at 0 — switching ALB rule to Lambda TG")
            switch_rule(rule_arn, lambda_tg_arn)
        else:
            print(f"Instance terminated but ASG still running (desired={asg['DesiredCapacity']}, in_service={in_service}) — no action")
        return

    action = event.get('action')
    if action == 'wait_and_switch_to_ec2':
        elbv2 = boto3.client('elbv2')
        print("Polling for healthy EC2 target...")
        for i in range(60):
            time.sleep(5)
            health = elbv2.describe_target_health(TargetGroupArn=ec2_tg_arn)
            healthy = [t for t in health['TargetHealthDescriptions']
                       if t['TargetHealth']['State'] == 'healthy']
            if healthy:
                print(f"EC2 healthy after {(i + 1) * 5}s — switching ALB rule to EC2 TG")
                switch_rule(rule_arn, ec2_tg_arn)
                elbv2.modify_target_group(
                    TargetGroupArn=ec2_tg_arn,
                    HealthCheckIntervalSeconds=30,
                    HealthCheckTimeoutSeconds=5
                )
                print("Health check interval restored to 30s")
                return
        print("Timed out waiting for healthy EC2 target")

def switch_rule(rule_arn, target_group_arn):
    boto3.client('elbv2').modify_rule(
        RuleArn=rule_arn,
        Actions=[{'Type': 'forward', 'TargetGroupArn': target_group_arn}]
    )
    print(f"ALB rule switched to {target_group_arn}")
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "scale_from_zero_worker" {
  count         = !var.haproxy ? 1 : 0
  filename      = data.archive_file.scale_from_zero_worker_zip[0].output_path
  function_name = substr(replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-sfz-worker", ".", ""), 0, 64)
  role          = aws_iam_role.scale_from_zero[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 360

  source_code_hash = data.archive_file.scale_from_zero_worker_zip[0].output_base64sha256

  environment {
    variables = {
      ASG_NAME                = aws_autoscaling_group.iris.name
      LISTENER_RULE_ARN       = aws_lb_listener_rule.port443[0].arn
      EC2_TARGET_GROUP_ARN    = aws_lb_target_group.port443[0].arn
      LAMBDA_TARGET_GROUP_ARN = aws_lb_target_group.scale_from_zero_lambda[0].arn
    }
  }

  tags = local.merged_tags
}

# ---- LAMBDA TARGET GROUP (ALB routes to handler Lambda) ----

resource "aws_lb_target_group" "scale_from_zero_lambda" {
  count       = !var.haproxy ? 1 : 0
  name_prefix = substr(replace("${var.hostname_prefix}sfz", ".", ""), 0, 6)
  target_type = "lambda"
  tags        = local.merged_tags
}

resource "aws_lb_target_group_attachment" "scale_from_zero" {
  count            = !var.haproxy ? 1 : 0
  target_group_arn = aws_lb_target_group.scale_from_zero_lambda[0].arn
  target_id        = aws_lambda_function.scale_from_zero_handler[0].arn
  depends_on       = [aws_lambda_permission.scale_from_zero_alb]
}

resource "aws_lambda_permission" "scale_from_zero_alb" {
  count         = !var.haproxy ? 1 : 0
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_from_zero_handler[0].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.scale_from_zero_lambda[0].arn
}

# ---- SNS + CW ALARM (ASG hits 0 → worker switches ALB rule to Lambda TG) ----

resource "aws_sns_topic" "scale_from_zero" {
  count = !var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-scale-from-zero", ".", "")
  tags  = local.merged_tags
}

resource "aws_sns_topic_subscription" "scale_from_zero" {
  count     = !var.haproxy ? 1 : 0
  topic_arn = aws_sns_topic.scale_from_zero[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.scale_from_zero_worker[0].arn
}

resource "aws_lambda_permission" "scale_from_zero_sns" {
  count         = !var.haproxy ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_from_zero_worker[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.scale_from_zero[0].arn
}

resource "aws_autoscaling_notification" "scale_from_zero" {
  count       = !var.haproxy ? 1 : 0
  group_names = [aws_autoscaling_group.iris.name]
  topic_arn   = aws_sns_topic.scale_from_zero[0].arn

  notifications = [
    "autoscaling:EC2_INSTANCE_TERMINATE",
  ]
}

# ---- IAM (shared role for both Lambdas) ----

resource "aws_iam_role" "scale_from_zero" {
  count = !var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-${data.aws_region.current.region}-scale-from-zero-role", ".", "")

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
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:DescribeAutoScalingGroups", "autoscaling:UpdateAutoScalingGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyTargetGroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "*"
      }
    ]
  })
}
