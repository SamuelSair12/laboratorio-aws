terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. TABLAS DYNAMODB
resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "idempotency" {
  name         = "Idempotencia"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "idempotency_key"

  attribute {
    name = "idempotency_key"
    type = "S"
  }
}

# 2. COLAS SQS Y DLQs
resource "aws_sqs_queue" "payments_dlq" {
  name = "payments-dlq"
}

resource "aws_sqs_queue" "payments_queue" {
  name = "payments-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payments_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "inventory_dlq" {
  name = "inventory-dlq"
}

resource "aws_sqs_queue" "inventory_queue" {
  name = "inventory-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.inventory_dlq.arn
    maxReceiveCount     = 3
  })
}

# 3. EVENTBRIDGE RULE & TARGETS
resource "aws_cloudwatch_event_rule" "order_created" {
  name        = "OrderCreatedRule"
  description = "Captura evento OrderCreated y lo distribuye a Payments e Inventory"

  event_pattern = jsonencode({
    "detail-type" = ["OrderCreated"]
  })
}

resource "aws_cloudwatch_event_target" "target_payments" {
  rule      = aws_cloudwatch_event_rule.order_created.name
  target_id = "PaymentsQueueTarget"
  arn       = aws_sqs_queue.payments_queue.arn
}

resource "aws_cloudwatch_event_target" "target_inventory" {
  rule      = aws_cloudwatch_event_rule.order_created.name
  target_id = "InventoryQueueTarget"
  arn       = aws_sqs_queue.inventory_queue.arn
}
