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

variable "jar_path" {
  description = "Shaded jar of the Orders handler (mvn package)."
  type        = string
  default     = "build/orders-handler.jar"
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
      lambda = "http://localhost:4566"
      iam    = "http://localhost:4566"
    }
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "orders" {
  name               = "orders-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_lambda_function" "orders" {
  function_name    = "orders-handler"
  role             = aws_iam_role.orders.arn
  runtime          = "java21"
  handler          = "com.example.orders.Handler::handleRequest"
  filename         = var.jar_path
  source_code_hash = try(filebase64sha256(var.jar_path), null)
  memory_size      = 1024
  timeout          = 10
  publish          = true # SnapStart only applies to published versions

  snap_start {
    apply_on = "PublishedVersions"
  }
}

# Callers must target the alias (or version), not $LATEST, to get SnapStart.
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.orders.function_name
  function_version = aws_lambda_function.orders.version
}

output "alias_arn" {
  value = aws_lambda_alias.live.arn
}
