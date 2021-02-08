data "template_file" "iris_role" {
  template = "${file("${path.module}/role.json")}"
}

data "template_file" "iris_policy" {
  template = "${file("${path.module}/policy.json")}"
}

resource "aws_iam_role" "iris" {
  name               = "${var.hostname_prefix}"
  assume_role_policy = "${data.template_file.iris_role.rendered}"
}

resource "aws_iam_instance_profile" "iris" {
  name = "${var.hostname_prefix}"
  role = "${aws_iam_role.iris.name}"
}

resource "aws_iam_policy" "iris" {
  name   = "${var.hostname_prefix}"
  policy = "${data.template_file.iris_policy.rendered}"
}

resource "aws_iam_role_policy_attachment" "iris" {
  policy_arn = "${aws_iam_policy.iris.arn}"
  role       = "${aws_iam_role.iris.name}"
}
