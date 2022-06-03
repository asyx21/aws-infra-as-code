

##############################
# Load Balancer
##############################

resource "aws_alb" "fargate" {
  name            = "${terraform.workspace}-${var.app_name}-alb"
  subnets         = aws_subnet.fargate_public.*.id
  security_groups = [aws_security_group.alb.id]

  access_logs {
    bucket  = aws_s3_bucket.fargate.bucket
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket.fargate]

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

resource "aws_alb_target_group" "fargate" {
  name        = "${terraform.workspace}-${var.app_name}-alb-tg2"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

resource "aws_alb_listener" "fargate" {
  load_balancer_arn = aws_alb.fargate.id
  port              = local.https ? "443" : "80"
  protocol          = local.https ? "HTTPS" : "HTTP"
  certificate_arn   = local.https ? var.cert_arn : ""

  default_action {
    target_group_arn = aws_alb_target_group.fargate.arn
    type             = "forward"
  }

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

# Redirection from HTTPS to HTTP
resource "aws_lb_listener" "front_end" {
  count             = local.https ? 1 : 0
  load_balancer_arn = aws_alb.fargate.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}
