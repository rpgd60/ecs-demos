variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "profile" {
  type    = string
  default = "madmin"
}

variable "company" {
  type    = string
  default = "Acme"
}

variable "project" {
  type    = string
  default = "ecs-poc"
}

variable "environment" {
  type    = string
  default = "test"
}

## VPC - Subnets - AZs
variable "az_count" {
  type        = number
  description = "Number of AZs to deploy"
  validation {
    condition     = var.az_count == 2
    error_message = "Number of Availability Zones must be 2"
  }
  default = 2
}

variable "vpc_cidr" {
  description = "CIDR block for main"
  type        = string
  default     = "10.77.0.0/16"
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t3.micro"
}