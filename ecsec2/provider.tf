terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~>2.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = "~> 1.7"
}

provider "docker" {}

provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      "${var.company}:environment" = var.environment
      "${var.company}:project"     = var.project
      "${var.company}:created_by"  = "terraform"
    }
  }
}

