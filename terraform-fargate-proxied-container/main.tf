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

  # Allow ingress from container to container on VPC
  ingress {
    protocol        = "tcp"
    from_port       = var.proxy_port
    to_port         = var.echo_port
    cidr_blocks     = [data.aws_vpc.main.cidr_block]
  }
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
resource "aws_lb_target_group" "alb_ecs_tg" {
  for_each    = local.service_config
  name        = "${terraform.workspace}-${var.app_name}-tg-${each.value.name}"
  port        = each.value.target_group.port
  protocol    = each.value.target_group.protocol
  target_type = "ip"
  vpc_id      = data.aws_vpc.main.id
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    interval    = 60
    matcher     = "200,202"
    path        = each.value.target_group.health_check_path
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
        message        = "Use defined routes to access servers"
        routes         = ["/proxy*", "/echo*"]
      })
      status_code  = "200"
    }
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_lb_listener_rule" "proxy_route" {
  for_each = local.service_config
  listener_arn = aws_lb_listener.ecs_alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ecs_tg[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.target_group.path_pattern
    }
  }
}

##############################
# ECS Cluster
##############################
# Create the ECS Cluster and Fargate launch type service in the private subnets
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${terraform.workspace}-${var.app_name}-cluster"
  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_ecs_service" "mock_ecs_service" {
  for_each        = local.service_config
  depends_on      = [
    aws_lb_listener.ecs_alb_listener,
    aws_service_discovery_service.service_discoveries,
  ]
  name            = "${terraform.workspace}-${var.app_name}-${each.value.name}-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.service_taskdef[each.key].arn

  desired_count   = each.value.desired_count
  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 50
  enable_ecs_managed_tags = false
  health_check_grace_period_seconds = 180
  launch_type = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_ecs_tg[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }

  service_registries {
    registry_arn      = aws_service_discovery_service.service_discoveries[each.key].arn
    container_name    = each.value.name
  }

  network_configuration {
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_security_group.id]
    subnets = var.private_subnets
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_ecs_task_definition" "service_taskdef" {
  for_each         = local.service_config
  family           = "${lower(var.app_name)}-${each.value.name}"
  container_definitions = jsonencode([
    {
      name         = each.value.name
      image        = each.value.image
      essential    = true
      cpu          = each.value.cpu
      memory       = each.value.memory
      portMappings = [
        {
          containerPort = each.value.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ecs_cluster.name}",
          awslogs-region        = var.region,
          awslogs-stream-prefix = var.app_name
        }
      }
      environment = each.value.environment
    }
  ])
  cpu                       = each.value.cpu
  memory                    = each.value.memory
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"

  execution_role_arn        = aws_iam_role.ecs_task_role.arn
  task_role_arn             = aws_iam_role.ecs_task_role.arn

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

#####################################################
# Service Discovery for inter-service communication
#####################################################
resource "aws_service_discovery_private_dns_namespace" "sd_namespace" {
  name            = "${terraform.workspace}.${var.app_name}.sd"
  description     = "${terraform.workspace}-${var.app_name} service discovery namespace"
  vpc             = data.aws_vpc.main.id

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_service_discovery_service" "service_discoveries" {
  for_each         = local.service_config
  name             = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.sd_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }
    # routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 3
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

##############################
# API Gateway HTTP
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

##############################
# API Gateway Websocket
##############################
# resource "aws_apigatewayv2_api" "ws_api" {
#   name                = "${terraform.workspace}-${var.app_name}-ws-endpoint"
#   protocol_type       = "WEBSOCKET"
#   route_selection_expression = "$request.body.action"

#   tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
# }
