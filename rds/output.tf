output "endpoint" {
  value = "${element(split(":", "${aws_db_instance.default.endpoint}"), 0)}"
}