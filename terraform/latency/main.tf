resource "aws_alb_target_group" "latency" {
  name = "latency-${var.env_name}"
  port = 1234
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
}


resource "aws_lb_listener_rule" "static" {
  listener_arn = "${var.listener}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.latency.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/latency/*"]
  }
}

resource "aws_ecs_task_definition" "main" {
  family                = "latency-${var.env_name}"
  container_definitions = "${file("${path.module}/containers.tmpl")}"
  cpu = "256"
  memory = "512"
  //task_role_arn = "arn:aws:iam::401701269211:role/ecsTaskExecutionRole"
  network_mode = "host"
}

resource "aws_ecs_service" "main" {
  name = "latency-${var.env_name}"
  task_definition = "${aws_ecs_task_definition.main.arn}"
  cluster = "${var.cluster}"
  desired_count = 1
  load_balancer {
    container_name = "latency"
    container_port = 1234
    target_group_arn = "${aws_alb_target_group.latency.arn}"
  }
}