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

variable "subnet_ids" {
  description = "At least two subnets in different AZs."
  type        = list(string)
  default     = ["subnet-aaaa1111", "subnet-bbbb2222"]
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
      rds = "http://localhost:4566"
    }
  }
}

resource "aws_db_subnet_group" "orders" {
  name       = "orders-db"
  subnet_ids = var.subnet_ids
}

# Multi-AZ standby gives automatic failover; it is NOT a read replica.
resource "aws_db_instance" "orders" {
  identifier                  = "orders-pg"
  engine                      = "postgres"
  engine_version              = "16.4"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  db_name                     = "orders"
  username                    = "orders_admin"
  manage_master_user_password = true # password lives in Secrets Manager, not in state or git
  multi_az                    = true
  db_subnet_group_name        = aws_db_subnet_group.orders.name
  backup_retention_period     = 7
  storage_encrypted           = true
  deletion_protection         = false # lab only; set true in real use
  skip_final_snapshot         = true  # lab only
}

output "endpoint" {
  value = aws_db_instance.orders.endpoint
}
