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

variable "image_name" {
  type        = string
  default     = "nginx"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags for Terraform owned resources"
  default     = {
    Owner       = "Terraform"
  }
}
