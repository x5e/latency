resource "aws_ecr_repository" "latency" {
  name = "latency-${var.env_name}"
}

