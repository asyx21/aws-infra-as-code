##############################
# Cloudwatch
##############################
# Cloudwatch log group and S3 Bucket to store logs from the service
resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name = "/ecs/${terraform.workspace}-${var.app_name}"
  retention_in_days = 7

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_s3_bucket" "ecs_cluster" {
  bucket        = "${terraform.workspace}-${var.app_name}-alb-logs"
  force_destroy = "true"

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_s3_bucket_acl" "ecs_cluster" {
  bucket          = aws_s3_bucket.ecs_cluster.bucket
  acl             = "private"
}

##########################################
# Allow ALB to log to S3 Bucket
##########################################
data "aws_elb_service_account" "main" {
}

data "aws_iam_policy_document" "ecs_cluster" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.ecs_cluster.arn}/alb/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ecs_cluster" {
  bucket = aws_s3_bucket.ecs_cluster.bucket
  policy = data.aws_iam_policy_document.ecs_cluster.json
}

##########################################
# Allow Fargate to publish to logs
##########################################
data "aws_iam_policy_document" "log_publishing" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["arn:aws:logs:${var.region}:*:log-group:/ecs/${terraform.workspace}-${var.app_name}:*"]
  }
}

resource "aws_iam_policy" "ecs_log_publishing" {
  name        = "${terraform.workspace}-${var.app_name}-log-pub"
  path        = "/"
  description = "Allow publishing to cloudwach"

  policy = data.aws_iam_policy_document.log_publishing.json
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

##############################
# ECS Task roles
##############################
# ECS task execution role and the task role is used which can be attached with additional IAM policies to configure the required permissions.
resource "aws_iam_role" "ecs_task_role" {
  name               = "${terraform.workspace}-${var.app_name}-ecs_task_role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_role_log_publishing" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_log_publishing.arn
}
