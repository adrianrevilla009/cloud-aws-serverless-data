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
      apigateway = "http://localhost:4566"
      cognitoidp = "http://localhost:4566"
    }
  }
}

resource "aws_cognito_user_pool" "orders" {
  name                     = "orders-users"
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length  = 12
    require_symbols = true
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name                = "orders-web"
  user_pool_id        = aws_cognito_user_pool.orders.id
  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

resource "aws_api_gateway_rest_api" "orders" {
  name = "orders-api"
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito"
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.orders.arn]
}

resource "aws_api_gateway_method" "get_orders" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# MOCK integration keeps the lab free of a backend; swap for AWS_PROXY to a Lambda.
resource "aws_api_gateway_integration" "mock" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.get_orders.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "ok" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.get_orders.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "ok" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.get_orders.http_method
  status_code = aws_api_gateway_method_response.ok.status_code
}

resource "aws_api_gateway_deployment" "v1" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  depends_on  = [aws_api_gateway_integration.mock, aws_api_gateway_integration_response.ok]

  triggers = {
    redeploy = sha1(jsonencode([aws_api_gateway_method.get_orders, aws_api_gateway_integration.mock]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  deployment_id = aws_api_gateway_deployment.v1.id
  stage_name    = "dev"
}
