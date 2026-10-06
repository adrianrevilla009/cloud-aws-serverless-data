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
      sqs    = "http://localhost:4566"
      sns    = "http://localhost:4566"
      events = "http://localhost:4566"
    }
  }
}

# Fan-out: Orders topic -> billing queue (with DLQ).
resource "aws_sns_topic" "orders" {
  name = "orders-events"
}

resource "aws_sqs_queue" "billing_dlq" {
  name = "billing-dlq"
}

resource "aws_sqs_queue" "billing" {
  name                       = "billing"
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.billing_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic_subscription" "billing" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.billing.arn
  raw_message_delivery = true
}

data "aws_iam_policy_document" "allow_sns" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.billing.arn]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.orders.arn]
    }
  }
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.billing.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.large_orders.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "billing" {
  queue_url = aws_sqs_queue.billing.id
  policy    = data.aws_iam_policy_document.allow_sns.json
}

# Content routing: EventBridge rule matches only large orders.
resource "aws_cloudwatch_event_bus" "orders" {
  name = "orders"
}

resource "aws_cloudwatch_event_rule" "large_orders" {
  name           = "large-orders"
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  event_pattern = jsonencode({
    source        = ["shop.orders"]
    "detail-type" = ["OrderPlaced"]
    detail        = { total = [{ numeric = [">=", 1000] }] }
  })
}

resource "aws_cloudwatch_event_target" "large_to_sqs" {
  rule           = aws_cloudwatch_event_rule.large_orders.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  arn            = aws_sqs_queue.billing.arn
}
