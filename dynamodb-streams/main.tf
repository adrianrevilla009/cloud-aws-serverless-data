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
  description = "Shaded jar of the stream consumer."
  type        = string
  default     = "build/stream-consumer.jar"
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
      dynamodb = "http://localhost:4566"
      lambda   = "http://localhost:4566"
      iam      = "http://localhost:4566"
      sqs      = "http://localhost:4566"
    }
  }
}

resource "aws_dynamodb_table" "orders" {
  name             = "orders"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "orderId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "orderId"
    type = "S"
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

resource "aws_iam_role" "consumer" {
  name               = "orders-stream-consumer"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "streams" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
}

resource "aws_sqs_queue" "failures" {
  name = "orders-stream-failures"
}

data "aws_iam_policy_document" "failures" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.failures.arn]
  }
}

resource "aws_iam_role_policy" "failures" {
  name   = "send-failures"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.failures.json
}

resource "aws_lambda_function" "consumer" {
  function_name = "orders-stream-consumer"
  role          = aws_iam_role.consumer.arn
  runtime       = "java21"
  handler       = "com.example.orders.StreamHandler::handleRequest"
  filename      = var.jar_path
  timeout       = 30
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn                   = aws_dynamodb_table.orders.stream_arn
  function_name                      = aws_lambda_function.consumer.arn
  starting_position                  = "LATEST"
  batch_size                         = 100
  maximum_retry_attempts             = 3
  bisect_batch_on_function_error     = true
  function_response_types            = ["ReportBatchItemFailures"]
  maximum_batching_window_in_seconds = 5

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.failures.arn
    }
  }
}
