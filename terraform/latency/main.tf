resource "aws_ecs_task_definition" "main" {
  family                = "latency-${var.env_name}"
  container_definitions = "${file("${path.module}/containers.tmpl")}"
  cpu = "256"
  memory = "512"
  //task_role_arn = "arn:aws:iam::401701269211:role/ecsTaskExecutionRole"
  network_mode = "host"
}