variable "region" {
  type        = string
  description = "AWS region resources will be deployed in."
  default     = "eu-central-1"
}

variable "app_name" {
  type        = string
  description = "The name of the app in this fargate cluster."
}

variable "private_subnets" {
  type        = list(any)
}

variable "cert_arn" {
  type        = string
  description = "ARN path to certificate resource"
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "Application DNS"
  default     = "my.domain.com"
}

# Mock server config
variable "image_proxy" {
  type        = string
  default     = "mockserver/mockserver"
}
variable "proxy_port" {
  type        = number
  default     = 1080
}
variable "proxy_envs" {
  description = "A map of secrets environment variables for 'mock' server container"
  type        = list
}

# Echo server config
variable "image_echo" {
  type        = string
  default     = "ealen/echo-server:latest"
}
variable "echo_port" {
  type        = number
  default     = 1081
}
variable "echo_envs" {
  description = "A map of secrets environment variables for 'echo' server container"
  type        = list
}

# Default tags
variable "default_tags" {
  type        = map(string)
  description = "Default tags for Terraform owned resources"
  default     = {
    Owner       = "Terraform"
  }
}
