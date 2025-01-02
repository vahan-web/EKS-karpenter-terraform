terraform {
  backend "s3" {
    bucket               = "project-terraform-state"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    encrypt              = true
    workspace_key_prefix = "workspaces"

  }
}

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.18.0"
    }
  }
}

