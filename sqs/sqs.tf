resource "aws_sqs_queue" "iris_qa_sqs" {
  name                    = var.sqs_name
  sqs_managed_sse_enabled = true

  tags = merge(
    var.additional_tags, {
    Name = "IrisAdmin" },
  )
}

resource "aws_sqs_queue_policy" "my_sqs_policy" {
  queue_url = aws_sqs_queue.iris_qa_sqs.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspol",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["SQS:SendMessage"],
      "Resource": "${aws_sqs_queue.iris_qa_sqs.arn}"
    }
  ]
}
POLICY
}