# Reference existing resources
data "aws_vpc" "main" {
}

locals {
  dns_enabled = (var.cert_arn != "") && (var.domain_name != "") ? true : false
}

##############################
# Networking
##############################
# Load balancer security group. CIDR and port ingress can be changed as required.
resource "aws_security_group" "lb_security_group" {
  name        = "${terraform.workspace}-${var.app_name}-alb"
  description = "LoadBalancer Security Group"
  vpc_id = data.aws_vpc.main.id

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_security_group_rule" "sg_ingress_rule_public_to_lb" {
  type	= "ingress"
  description = "Allow from anyone on port 80"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.lb_security_group.id
}

# Load balancer security group egress rule to ECS cluster security group.
resource "aws_security_group_rule" "sg_egress_rule_lb_ecs" {
  type	= "egress"
  description = "ECS target group egress"
  from_port         = var.proxy_port
  to_port           = var.echo_port
  protocol          = "tcp"
  security_group_id = aws_security_group.lb_security_group.id
  source_security_group_id = aws_security_group.ecs_security_group.id
}

# ECS cluster security group.
resource "aws_security_group" "ecs_security_group" {
  name        = "${terraform.workspace}-${var.app_name}-ecs"
  description = "ECS Security Group"
  vpc_id = data.aws_vpc.main.id
  egress {
    description      = "Allow all outbound traffic by default"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# ECS cluster security group ingress from the load balancer.
resource "aws_security_group_rule" "sg_ingress_rule_ecs_from_lb" {
  type	= "ingress"
  description = "ECS ingress from Load Balancer"
  from_port         = var.proxy_port
  to_port           = var.echo_port
  protocol          = "tcp"
  security_group_id = aws_security_group.ecs_security_group.id
  source_security_group_id = aws_security_group.lb_security_group.id
}

##############################
# Load Balancer
##############################
# Create the internal application load balancer (ALB) in the private subnets.
resource "aws_lb" "ecs_alb" {
  name                = "${terraform.workspace}-${var.app_name}-alb"
  load_balancer_type  = "application"
  internal            = true
  subnets             = var.private_subnets
  security_groups     = [aws_security_group.lb_security_group.id]

  depends_on = [aws_s3_bucket.ecs_cluster]
  access_logs {
    bucket  = aws_s3_bucket.ecs_cluster.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the ALB target group for 'proxy' server on ECS.
resource "aws_lb_target_group" "alb_ecs_tg_proxy" {
  name        = "${terraform.workspace}-${var.app_name}-tg-proxy"
  port        = var.proxy_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.main.id
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    interval    = 60
    matcher     = "200,201,202"
    path        = "/"
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the ALB target group for 'echo' server on ECS.
resource "aws_lb_target_group" "alb_ecs_tg_echo" {
  name        = "${terraform.workspace}-${var.app_name}-tg-echo"
  port        = var.echo_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.main.id
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    interval    = 60
    matcher     = "200,201,202"
    path        = "/"
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the ALB listener with the target group.
resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        message        = "Use 'proxy' route to access echo server"
        routes         = ["/proxy/*"]
      })
      status_code  = "200"
    }
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_lb_listener_rule" "proxy_route" {
  listener_arn = aws_lb_listener.ecs_alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ecs_tg_proxy.arn
  }

  condition {
    path_pattern {
      values = ["/proxy/*"]
    }
  }
}

## Ucomment to access 'echo' server directly on /echo route bypassing 'proxy' server
# resource "aws_lb_listener_rule" "echo_route" {
#   listener_arn = aws_lb_listener.ecs_alb_listener.arn

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.alb_ecs_tg_echo.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/echo/*"]
#     }
#   }
# }

##############################
# ECS Cluster
##############################
# Create the ECS Cluster and Fargate launch type service in the private subnets
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${terraform.workspace}-${var.app_name}-cluster"
  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_ecs_service" "proxy_ecs_service" {
  depends_on      = [
    aws_lb_target_group.alb_ecs_tg_echo,
    aws_lb_target_group.alb_ecs_tg_proxy,
    aws_lb_listener.ecs_alb_listener,
  ]
  name            = "${terraform.workspace}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id

  task_definition = aws_ecs_task_definition.ecs_taskdef.arn
  desired_count   = 1
  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 50
  enable_ecs_managed_tags = false
  health_check_grace_period_seconds = 180
  launch_type = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_ecs_tg_proxy.arn
    container_name   = "proxy"
    container_port   = var.proxy_port
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_ecs_tg_echo.arn
    container_name   = "echo"
    container_port   = var.echo_port
  }

  network_configuration {
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_security_group.id]
    subnets = var.private_subnets
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the ECS Service task definition. 
resource "aws_ecs_task_definition" "ecs_taskdef" {
  family = "mock-server"
  container_definitions = jsonencode([
    {
      name      = "proxy"
      image     = var.image_proxy
      essential = true
      portMappings = [
        {
          containerPort = var.proxy_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ecs_cluster.name}",
          awslogs-region        = "${var.region}",
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = var.proxy_envs
    },
    {
      name      = "echo"
      image     = var.image_echo
      essential = true
      portMappings = [
        {
          containerPort = var.echo_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ecs_cluster.name}",
          awslogs-region        = "${var.region}",
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = var.echo_envs
    }
  ])
  cpu                       = 256
  memory                    = 512
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"

  execution_role_arn        = aws_iam_role.ecs_task_role.arn
  task_role_arn             = aws_iam_role.ecs_task_role.arn

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

##############################
# API Gateway
##############################
# Create the VPC Link configured with the private subnets. Security groups are kept empty here, but can be configured as required.
resource "aws_apigatewayv2_vpc_link" "vpclink_apigw_to_alb" {
  name                = "${terraform.workspace}-${var.app_name}-apigw"
  security_group_ids  = []
  subnet_ids          = var.private_subnets

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the API Gateway HTTP endpoint
resource "aws_apigatewayv2_api" "apigw_http_endpoint" {
  name                = "${terraform.workspace}-${var.app_name}-endpoint"
  protocol_type       = "HTTP"

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

# Create the API Gateway HTTP_PROXY integration between the created API and the private load balancer via the VPC Link.
# Ensure that the 'DependsOn' attribute has the VPC Link dependency.
# This is to ensure that the VPC Link is created successfully before the integration and the API GW routes are created.
resource "aws_apigatewayv2_integration" "apigw_integration" {
  depends_on = [
    aws_apigatewayv2_vpc_link.vpclink_apigw_to_alb,
    aws_apigatewayv2_api.apigw_http_endpoint,
    aws_lb_listener.ecs_alb_listener
  ]
  api_id                  = aws_apigatewayv2_api.apigw_http_endpoint.id
  integration_type        = "HTTP_PROXY"
  integration_uri         = aws_lb_listener.ecs_alb_listener.arn

  integration_method      = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_apigatewayv2_vpc_link.vpclink_apigw_to_alb.id
  payload_format_version  = "1.0"
}

# API GW route with ANY method
resource "aws_apigatewayv2_route" "apigw_route" {
  depends_on  = [aws_apigatewayv2_integration.apigw_integration]
  api_id    = aws_apigatewayv2_api.apigw_http_endpoint.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.apigw_integration.id}"
}

# Set a default stage
resource "aws_apigatewayv2_stage" "apigw_stage" {
  depends_on  = [aws_apigatewayv2_api.apigw_http_endpoint]
  api_id      = aws_apigatewayv2_api.apigw_http_endpoint.id
  # name        = "${terraform.workspace}-${var.app_name}-http"
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_domain_name" "api_domain" {
  count       = local.dns_enabled ? 1 : 0
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn   = var.cert_arn
    endpoint_type     = "REGIONAL"
    security_policy   = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "domain_map" {
  count       = local.dns_enabled ? 1 : 0
  api_id      = aws_apigatewayv2_api.apigw_http_endpoint.id
  domain_name = aws_apigatewayv2_domain_name.api_domain[0].id
  stage       = aws_apigatewayv2_stage.apigw_stage.id
}
