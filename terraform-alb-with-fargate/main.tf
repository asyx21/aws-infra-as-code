locals {
  ecs_container_definitions = [
    {
      image       = var.image_name
      name        = "${terraform.workspace}-${var.app_name}",
      networkMode = "awcvpc",

      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.fargate.name}",
          awslogs-region        = "${var.region}",
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = var.app_envs
    }
  ]

  https       = var.https_enabled
}

# Reference to existing resources
data "aws_availability_zones" "available" {
}

data "aws_vpc" "main" {
}

##############################
# ECS
##############################
resource "aws_ecs_task_definition" "fargate" {
  family                   = var.task_group_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_units
  memory                   = var.ram_units
  execution_role_arn       = aws_iam_role.fargate_role.arn
  task_role_arn            = aws_iam_role.fargate_role.arn

  container_definitions = jsonencode(local.ecs_container_definitions)

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_ecs_cluster" "fargate" {
  name = "${terraform.workspace}-${var.app_name}-cluster"

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_ecs_cluster_capacity_providers" "fargate" {
  cluster_name = aws_ecs_cluster.fargate.name

  capacity_providers = ["FARGATE"] # ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = var.capacity_provider
  }
}

resource "aws_ecs_service" "fargate" {
  depends_on = [
    aws_ecs_task_definition.fargate,
    aws_cloudwatch_log_group.fargate,
    aws_alb_listener.fargate,
    aws_alb_target_group.fargate,
    aws_alb.fargate
  ]
  name                               = "${terraform.workspace}-${var.app_name}-service"
  cluster                            = aws_ecs_cluster.fargate.id
  task_definition                    = aws_ecs_task_definition.fargate.arn
  desired_count                      = var.desired_tasks
  deployment_maximum_percent         = var.maxiumum_healthy_task_percent
  deployment_minimum_healthy_percent = var.minimum_healthy_task_percent

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 100
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.fargate_ecs.id]
    subnets          = aws_subnet.fargate_ecs.*.id
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.fargate.arn
    container_name   = "${terraform.workspace}-${var.app_name}"
    container_port   = var.container_port
  }

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}
