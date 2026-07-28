# ---- SUMMARY ROUTER LAMBDA ----
# Intercepts /irisanywhere/api/sessions/summary on the login page.
# If capacity is available: clears AWSALB + redirects so LOR picks a fresh instance.
# If all instances full: returns full-capacity JSON so the app shows "no capacity."
#
# Flow:
#   1. No _ia_rerouting cookie + capacity exists → 302 to same URL, clear AWSALB, set _ia_rerouting=1
#   2. _ia_rerouting cookie present + capacity exists → return synthesized available JSON
#   3. All instances full (IrisAvailableSessions == 0) → return full-capacity JSON

data "archive_file" "summary_router_zip" {
  count       = !var.haproxy ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/summary_router.zip"

  source {
    content  = <<EOF
import boto3, json, os
from datetime import datetime, timezone, timedelta


def get_available_sessions(asg_name):
    cw = boto3.client("cloudwatch")
    end_time = datetime.now(timezone.utc)
    response = cw.get_metric_statistics(
        Namespace="AWS/EC2",
        MetricName="IrisAvailableSessions",
        Dimensions=[{"Name": "AutoScalingGroupName", "Value": asg_name}],
        StartTime=end_time - timedelta(minutes=3),
        EndTime=end_time,
        Period=60,
        Statistics=["Sum"],
    )
    datapoints = response.get("Datapoints", [])
    if not datapoints:
        return None  # No data yet — treat as available
    return int(max(datapoints, key=lambda x: x["Timestamp"])["Sum"])


def parse_cookies(header):
    cookies = {}
    if not header:
        return cookies
    for part in header.split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            cookies[k.strip()] = v.strip()
        else:
            cookies[part] = ""
    return cookies


def json_response(status, body):
    return {
        "statusCode": status,
        "statusDescription": f"{status} OK",
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
        "isBase64Encoded": False,
    }


def handler(event, context):
    max_sessions = int(os.environ.get("MAX_SESSIONS", "1"))
    asg_name = os.environ["ASG_NAME"]

    h = event.get("headers") or {}
    cookies = parse_cookies(h.get("cookie") or h.get("Cookie") or "")

    available = get_available_sessions(asg_name)
    has_capacity = available is None or available > 0

    if not has_capacity:
        return json_response(200, {"sessions": {"max_sessions": max_sessions, "used_sessions": max_sessions}})

    if "_ia_rerouting" in cookies:
        # Second pass after redirect — return available so app shows the login form
        return json_response(200, {"sessions": {"max_sessions": max_sessions, "used_sessions": 0}})

    # First pass — clear AWSALB and bounce back through LOR for a fresh instance
    return {
        "statusCode": 302,
        "statusDescription": "302 Found",
        "multiValueHeaders": {
            "Location": ["/irisanywhere/api/sessions/summary"],
            "Set-Cookie": [
                "AWSALB=; Max-Age=0; Path=/",
                "AWSALBCORS=; Max-Age=0; Path=/",
                "_ia_rerouting=1; Max-Age=30; Path=/",
            ],
        },
        "body": "",
        "isBase64Encoded": False,
    }
EOF
    filename = "index.py"
  }
}

resource "aws_iam_role" "summary_router" {
  count = !var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-${data.aws_region.now.region}-summary-router-role", ".", "")

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

resource "aws_iam_role_policy" "summary_router" {
  count = !var.haproxy ? 1 : 0
  name  = "summary-router-policy"
  role  = aws_iam_role.summary_router[0].id

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
        Action   = ["cloudwatch:GetMetricStatistics"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "summary_router" {
  count            = !var.haproxy ? 1 : 0
  filename         = data.archive_file.summary_router_zip[0].output_path
  function_name    = substr(replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-summary-router", ".", ""), 0, 64)
  role             = aws_iam_role.summary_router[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 10
  source_code_hash = data.archive_file.summary_router_zip[0].output_base64sha256

  environment {
    variables = {
      ASG_NAME     = aws_autoscaling_group.iris.name
      MAX_SESSIONS = var.ia_max_sessions
    }
  }

  tags = local.merged_tags
}

resource "aws_lb_target_group" "summary_router" {
  count       = !var.haproxy ? 1 : 0
  name_prefix = substr(replace("${var.hostname_prefix}sr", ".", ""), 0, 6)
  target_type = "lambda"
  tags        = local.merged_tags
}

resource "aws_lb_target_group_attachment" "summary_router" {
  count            = !var.haproxy ? 1 : 0
  target_group_arn = aws_lb_target_group.summary_router[0].arn
  target_id        = aws_lambda_function.summary_router[0].arn
  depends_on       = [aws_lambda_permission.summary_router_alb]
}

resource "aws_lambda_permission" "summary_router_alb" {
  count         = !var.haproxy ? 1 : 0
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summary_router[0].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.summary_router[0].arn
}

resource "aws_lb_listener_rule" "summary_router" {
  count        = !var.haproxy ? 1 : 0
  listener_arn = aws_lb_listener.port443[0].arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.summary_router[0].arn
  }

  condition {
    path_pattern {
      values = ["/irisanywhere/api/sessions/summary"]
    }
  }
}
