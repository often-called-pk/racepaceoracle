# versions.tf - Specifies Terraform and provider version constraints for the F1 Telemetry WebApp

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0, < 5.0.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
    
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
    
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1.0"
    }
  }
}