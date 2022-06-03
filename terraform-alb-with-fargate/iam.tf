#########################################
# Create linked service role
# 
# This is safe to leave as false,
# unless this role has never been created
# in your AWS account.
##########################################
resource "aws_iam_service_linked_role" "ecs_service" {
  aws_service_name = "ecs.amazonaws.com"
  count            = var.create_iam_service_linked_role ? 1 : 0

  lifecycle {
    prevent_destroy = true
  }
}

##########################################
# Allow ALB to log to S3 Bucket
##########################################
data "aws_elb_service_account" "main" {
}

data "aws_iam_policy_document" "fargate" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.fargate.arn}/alb/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "fargate" {
  bucket = aws_s3_bucket.fargate.bucket
  policy = data.aws_iam_policy_document.fargate.json
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

resource "aws_iam_policy" "fargate_log_publishing" {
  name        = "${terraform.workspace}-${var.app_name}-log-pub"
  path        = "/"
  description = "Allow publishing to cloudwach"

  policy = data.aws_iam_policy_document.log_publishing.json
}

data "aws_iam_policy_document" "fargate_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate_role" {
  name               = "${terraform.workspace}-${var.app_name}-role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "fargate_role_log_publishing" {
  role       = aws_iam_role.fargate_role.name
  policy_arn = aws_iam_policy.fargate_log_publishing.arn
}

##########################################
# Allow to pull ECR images
##########################################
data "aws_iam_policy_document" "ecr_image_pull" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      "*", # This needs to be a wildcard so that the GetAuthorizationToken permission is granted
    ]
  }
}

resource "aws_iam_policy" "ecr_image_pull" {
  name        = "${terraform.workspace}-${var.app_name}-ecr"
  path        = "/"
  description = "Allow Fargate to interact with ECR"

  policy = data.aws_iam_policy_document.ecr_image_pull.json
}

resource "aws_iam_role_policy_attachment" "fargate_ecr" {
  role       = aws_iam_role.fargate_role.name
  policy_arn = aws_iam_policy.ecr_image_pull.arn
}

# # Acess ECR without going to the public internet via VPC 
# resource "aws_vpc_endpoint" "internal_vpc" {
#   count = var.az_count

#   vpc_id = data.aws_vpc.main.id
#   service_name = "com.amazonaws.${var.region}.ecr.dkr"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [
#     # module.fargate.private_security_group_id,
#     aws_security_group.fargate_ecs.id,
#   ]

#   subnet_ids = [
#     # module.fargate.private_subnets[count.index].id,
#     aws_subnet.fargate_ecs[count.index].id,
#   ]
# }