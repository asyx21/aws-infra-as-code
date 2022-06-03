variable "app_envs" {
  description = "A map of secrets environment variables that is passed into the application."
  type        = list
}

variable "aws_access_key" {
  description = "AWS access key."
  type = string
}

variable "aws_secret_key" {
  description = "AWS secret key."
  type = string
}

variable "region" {
  type        = string
  description = "AWS region resources will be deployed in."
}

variable "app_name" {
  type        = string
  description = "The name of the app in this fargate cluster."
}

variable "image_name" {
  type        = string
  description = "Name of the docker image to apply."
}

variable "cpu_units" {
  type        = string
  description = "CPU Units to allocate to task definition."
}

variable "ram_units" {
  type        = string
  description = "RAM units to allocate to task definition."
}

variable "task_group_family" {
  type        = string
  description = "Name of task group family."
}

variable "container_port" {
  type        = number
  description = "Container port for the container"
}

variable "cidr_bit_offset" {
  type        = string
  description = "Offset for CIDR mask when applying to existing VPC."
  default     = 8
}

# Example subnets, create new one to avoid conflicts !
variable "private_subnets" {
  default = ["172.31.52.0/24", "172.31.53.0/24"]
}

variable "public_subnets" {
  default = ["172.31.54.0/24", "172.31.55.0/24"]
}

variable "https_enabled" {
  type        = bool
  description = "Is Https enabled? Certifcate arn needs to be set if this is true"
  default     = false
}

variable "cert_arn" {
  type        = string
  description = "ARN path to certificate resource"
  default     = ""
}

variable "create_iam_service_linked_role" {
  type        = bool
  description = "Whether to create IAM service role for ECS. If you already have one in your account this can be false"
  default     = false
}

variable "az_count" {
  type        = string
  description = "Number of Availability zones to deploy into within region"
  default     = 2
}

variable "capacity_provider" {
  type        = string
  description = "capacity_provider (e.g. FARGATE or FARGATE_SPOT)"
  default     = "FARGATE"
}

variable "desired_tasks" {
  type        = number
  description = "Desired number of tasks running"
  default     = 1
}

variable "maxiumum_healthy_task_percent" {
  type        = number
  description = "Maxiumum Percent of healthy tasks"
  default     = 200
}

variable "minimum_healthy_task_percent" {
  type        = number
  description = "Minimum Percentage of tasks running"
  default     = 100
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags for Terraform owned resources"
  default     = {
    Owner       = "Terraform"
  }
}
