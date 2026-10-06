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
      stepfunctions = "http://localhost:4566"
      iam           = "http://localhost:4566"
    }
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "orders-sfn"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Order workflow: validate (reject if no total) -> choice on total -> wait for approval or auto-accept.
resource "aws_sfn_state_machine" "orders" {
  name     = "order-workflow"
  role_arn = aws_iam_role.sfn.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Orders approval workflow"
    StartAt = "Validate"
    States = {
      Validate = {
        Type = "Choice"
        Choices = [{
          Variable  = "$.total"
          IsPresent = true
          Next      = "CheckTotal"
        }]
        Default = "Reject"
      }
      CheckTotal = {
        Type = "Choice"
        Choices = [{
          Variable           = "$.total"
          NumericGreaterThan = 1000
          Next               = "WaitForApproval"
        }]
        Default = "Accept"
      }
      WaitForApproval = {
        Type    = "Wait"
        Seconds = 5
        Next    = "Accept"
      }
      Accept = {
        Type = "Succeed"
      }
      Reject = {
        Type  = "Fail"
        Error = "OrderRejected"
        Cause = "Validation failed"
      }
    }
  })
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.orders.arn
}
