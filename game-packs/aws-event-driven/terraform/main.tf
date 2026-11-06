data "archive_file" "orders" {
  type        = "zip"
  source_file = "${path.module}/../functions/orders/handler.py"
  output_path = "${path.module}/.build/orders.zip"
}
data "archive_file" "payments" {
  type        = "zip"
  source_file = "${path.module}/../functions/payments/handler.py"
  output_path = "${path.module}/.build/payments.zip"
}
data "archive_file" "inventory" {
  type        = "zip"
  source_file = "${path.module}/../functions/inventory/handler.py"
  output_path = "${path.module}/.build/inventory.zip"
}

resource "aws_dynamodb_table" "orders" {
  name         = "${var.name_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "orderId"
  attribute {
    name = "orderId"
    type = "S"
  }
}
resource "aws_dynamodb_table" "idempotency" {
  name         = "${var.name_prefix}-idempotency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key  = "eventId"
  range_key = "service"
  attribute {
    name = "eventId"
    type = "S"
  }
  attribute {
    name = "service"
    type = "S"
  }
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
}

resource "aws_sqs_queue" "payments_dlq" {
  name = "${var.name_prefix}-payments-dlq"
}
resource "aws_sqs_queue" "inventory_dlq" {
  name = "${var.name_prefix}-inventory-dlq"
}
resource "aws_sqs_queue" "payments" {
  name                       = "${var.name_prefix}-payments"
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({ deadLetterTargetArn = aws_sqs_queue.payments_dlq.arn, maxReceiveCount = 2 })
}
resource "aws_sqs_queue" "inventory" {
  name                       = "${var.name_prefix}-inventory"
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({ deadLetterTargetArn = aws_sqs_queue.inventory_dlq.arn, maxReceiveCount = 2 })
}

resource "aws_cloudwatch_event_bus" "orders" {
  name = "${var.name_prefix}-orders-bus"
}
resource "aws_cloudwatch_event_rule" "order_created" {
  name           = "${var.name_prefix}-order-created"
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  event_pattern  = jsonencode({ source = ["com.cloudopsarena.orders"], "detail-type" = ["OrderCreated"] })
}
resource "aws_cloudwatch_event_target" "payments" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  target_id      = "payments-queue"
  arn            = aws_sqs_queue.payments.arn
  depends_on     = [aws_sqs_queue_policy.payments_from_events]
}
resource "aws_cloudwatch_event_target" "inventory" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  target_id      = "inventory-queue"
  arn            = aws_sqs_queue.inventory.arn
  depends_on     = [aws_sqs_queue_policy.inventory_from_events]
}
resource "aws_sqs_queue_policy" "payments_from_events" {
  queue_url = aws_sqs_queue.payments.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Sid = "AllowEventBridgeSend", Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sqs:SendMessage", Resource = aws_sqs_queue.payments.arn, Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.order_created.arn } } }]
  })
}
resource "aws_sqs_queue_policy" "inventory_from_events" {
  queue_url = aws_sqs_queue.inventory.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Sid = "AllowEventBridgeSend", Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sqs:SendMessage", Resource = aws_sqs_queue.inventory.arn, Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.order_created.arn } } }]
  })
}

locals {
  lambda_trust = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role" "orders" {
  name               = "${var.name_prefix}-orders-role"
  assume_role_policy = local.lambda_trust
}
resource "aws_iam_role" "payments" {
  name               = "${var.name_prefix}-payments-role"
  assume_role_policy = local.lambda_trust
}
resource "aws_iam_role" "inventory" {
  name               = "${var.name_prefix}-inventory-role"
  assume_role_policy = local.lambda_trust
}

resource "aws_iam_role_policy" "orders" {
  name = "${var.name_prefix}-orders-policy"
  role = aws_iam_role.orders.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
    { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.orders.arn },
    { Effect = "Allow", Action = ["events:PutEvents"], Resource = aws_cloudwatch_event_bus.orders.arn }
  ] })
}
resource "aws_iam_role_policy" "consumers" {
  for_each = { payments = aws_iam_role.payments.id, inventory = aws_iam_role.inventory.id }
  name = "${var.name_prefix}-${each.key}-policy"
  role = each.value
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
    { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.idempotency.arn },
    { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"], Resource = each.key == "payments" ? aws_sqs_queue.payments.arn : aws_sqs_queue.inventory.arn }
  ] })
}

resource "aws_lambda_function" "orders" {
  function_name    = "${var.name_prefix}-orders"
  role             = aws_iam_role.orders.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.orders.output_path
  source_code_hash = data.archive_file.orders.output_base64sha256
  timeout          = 10
  memory_size      = 128
  environment { variables = { ORDERS_TABLE = aws_dynamodb_table.orders.name, EVENT_BUS_NAME = aws_cloudwatch_event_bus.orders.name, AWS_ENDPOINT_URL = var.use_floci ? var.lambda_endpoint_url : "", AWS_REGION = var.aws_region } }
}
resource "aws_lambda_function" "payments" {
  function_name    = "${var.name_prefix}-payments"
  role             = aws_iam_role.payments.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.payments.output_path
  source_code_hash = data.archive_file.payments.output_base64sha256
  timeout          = 10
  memory_size      = 128
  environment { variables = { IDEMPOTENCY_TABLE = aws_dynamodb_table.idempotency.name, FAIL_PAYMENTS = var.fail_payments ? "true" : "false", AWS_ENDPOINT_URL = var.use_floci ? var.lambda_endpoint_url : "", AWS_REGION = var.aws_region } }
}
resource "aws_lambda_function" "inventory" {
  function_name    = "${var.name_prefix}-inventory"
  role             = aws_iam_role.inventory.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.inventory.output_path
  source_code_hash = data.archive_file.inventory.output_base64sha256
  timeout          = 10
  memory_size      = 128
  environment { variables = { IDEMPOTENCY_TABLE = aws_dynamodb_table.idempotency.name, AWS_ENDPOINT_URL = var.use_floci ? var.lambda_endpoint_url : "", AWS_REGION = var.aws_region } }
}

resource "aws_lambda_event_source_mapping" "payments" {
  event_source_arn = aws_sqs_queue.payments.arn
  function_name    = aws_lambda_function.payments.arn
  batch_size       = 5
  function_response_types = ["ReportBatchItemFailures"]
  depends_on = [aws_iam_role_policy.consumers]
}
resource "aws_lambda_event_source_mapping" "inventory" {
  event_source_arn = aws_sqs_queue.inventory.arn
  function_name    = aws_lambda_function.inventory.arn
  batch_size       = 5
  function_response_types = ["ReportBatchItemFailures"]
  depends_on = [aws_iam_role_policy.consumers]
}

resource "aws_apigatewayv2_api" "orders" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
}
resource "aws_apigatewayv2_integration" "orders" {
  api_id                 = aws_apigatewayv2_api.orders.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.orders.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "create_order" {
  api_id    = aws_apigatewayv2_api.orders.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.orders.id}"
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.orders.id
  name        = "$default"
  auto_deploy = true
}
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.orders.execution_arn}/*/*"
}
