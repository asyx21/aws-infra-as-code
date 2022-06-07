output "cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.ecs_cluster.arn
}

output "iam_role" {
  description = "IAM role for the fargate cluster. Can be used to link additional IAM permissions."
  value       = aws_iam_role.ecs_task_role
}

# Generated public API GW endpoint URL to access private Fargate Cluster
output "apigw_endpoint" {
  value = aws_apigatewayv2_api.apigw_http_endpoint.api_endpoint
    description = "API Gateway Endpoint"
}
