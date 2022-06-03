##############################
# Network Interfaces
##############################

# Security group for public subnet holding load balancer
resource "aws_security_group" "alb" {
  name        = "${terraform.workspace}-${var.app_name}-alb"
  description = "Allow access on port 443 only to ALB"
  vpc_id      = data.aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

# Allow ingress rule appropriate to HTTP Protocol used
resource "aws_security_group_rule" "tcp_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}


resource "aws_security_group_rule" "tcp_80" {
  count = local.https ? 0 : 1

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Public subnet for ALB
resource "aws_subnet" "fargate_public" {
  count                   = var.az_count
  # cidr_block              = cidrsubnet(data.aws_vpc.main.cidr_block, 8, var.cidr_bit_offset + count.index)
  # cidr_block              = cidrsubnet("172.31.48.0/16", 8, var.cidr_bit_offset + count.index)
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = data.aws_vpc.main.id
  map_public_ip_on_launch = true

  tags = merge(
    var.default_tags,
    {
      Name = "${terraform.workspace} ${var.app_name} #${var.az_count + count.index} (public)"
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

# Private subnet to hold fargate container
resource "aws_subnet" "fargate_ecs" {
  count             = var.az_count
  # cidr_block        = cidrsubnet(data.aws_vpc.main.cidr_block, 8, var.cidr_bit_offset + var.az_count + count.index)
  # cidr_block        = cidrsubnet("172.31.48.0/16", 8, var.cidr_bit_offset + var.az_count + count.index)
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = data.aws_vpc.main.id

  tags = merge(
    var.default_tags,
    {
      Name = "${terraform.workspace} ${var.app_name} #${count.index} (private)"
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}

# Private subnet for the ECS - only allows access from the ALB
resource "aws_security_group" "fargate_ecs" {
  name        = "${terraform.workspace}-${var.app_name}-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = merge(
    var.default_tags,
    {
      Project      = var.app_name
      Environment  = terraform.workspace
    },
  )
}
