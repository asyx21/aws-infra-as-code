variable "region" {
  type        = string
  description = "AWS region resources will be deployed in."
  default     = "eu-central-1"
}

variable "private_subnets" {
  type        = list(any)
}

variable "image_name" {
  type        = string
  default     = "nginx"
}
