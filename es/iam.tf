resource "aws_iam_access_key" "iris_s3_index" {
  user = aws_iam_user.iris_s3_index.name
}

resource "aws_iam_user" "iris_s3_index" {
  name = "iris_s3_index"
}

resource "aws_iam_user_policy" "iris_s3_index" {
  name = "Iris_s3_Index"
  user = aws_iam_user.iris_s3_index.name

  policy = <<EOF
{
    "Version":"2012-10-17",
    "Statement":[
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:GetBucketVersioning",
                "s3:ListBucket",
                "s3:ListBucketVersions"
            ],
            "Resource": [
                "arn:aws:s3:::${var.bucketlist}"
            ]
       },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::${var.bucketlist}/*"
            ]
        }
    ]
 }

EOF
}