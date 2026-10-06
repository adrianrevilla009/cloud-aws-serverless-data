terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
}

variable "use_localstack" {
  type    = bool
  default = true
}

provider "aws" {
  region                      = "eu-west-1"
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      kinesis = "http://localhost:4566"
    }
  }
}

# Kinesis is the runnable path here. MSK is deliberately not declared: a cluster costs
# roughly $0.20+/hour per broker, is not in the free tier, and LocalStack MSK needs Pro.
resource "aws_kinesis_stream" "orders" {
  name             = "orders-stream"
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

# Enhanced fan-out: a dedicated 2 MB/s pipe per consumer instead of sharing read throughput.
resource "aws_kinesis_stream_consumer" "analytics" {
  name       = "analytics"
  stream_arn = aws_kinesis_stream.orders.arn
}

output "stream_name" {
  value = aws_kinesis_stream.orders.name
}
