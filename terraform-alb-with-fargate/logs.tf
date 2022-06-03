# Cloudwatch log group and S3 Bucket to store logs from the service
resource "aws_cloudwatch_log_group" "fargate" {
  name = "/ecs/${terraform.workspace}-${var.app_name}"
  retention_in_days = 7

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_s3_bucket" "fargate" {
  bucket        = "${terraform.workspace}-${var.app_name}-alb-logs"
  force_destroy = "true"

  tags = merge(var.default_tags, { Project = var.app_name, Environment = terraform.workspace })
}

resource "aws_s3_bucket_acl" "fargate" {
  bucket          = aws_s3_bucket.fargate.bucket
  acl             = "private"
}
