terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = var.use_floci ? (var.aws_access_key != "" ? var.aws_access_key : "test") : null
  secret_key                  = var.use_floci ? (var.aws_secret_key != "" ? var.aws_secret_key : "test") : null
  skip_credentials_validation = var.use_floci
  skip_metadata_api_check     = var.use_floci
  skip_requesting_account_id  = var.use_floci
  skip_region_validation      = var.use_floci
  s3_use_path_style           = true

  dynamic "endpoints" {
    for_each = var.use_floci ? [1] : []
    content {
      apigatewayv2 = var.endpoint_url
      dynamodb     = var.endpoint_url
      events       = var.endpoint_url
      iam          = var.endpoint_url
      lambda       = var.endpoint_url
      logs         = var.endpoint_url
      sqs          = var.endpoint_url
      sts          = var.endpoint_url
    }
  }
}
