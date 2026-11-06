output "orders_api_url" { value = aws_apigatewayv2_api.orders.api_endpoint }
output "event_bus_name" { value = aws_cloudwatch_event_bus.orders.name }
output "payments_queue_url" { value = aws_sqs_queue.payments.url }
output "payments_dlq_url" { value = aws_sqs_queue.payments_dlq.url }
output "inventory_queue_url" { value = aws_sqs_queue.inventory.url }
output "inventory_dlq_url" { value = aws_sqs_queue.inventory_dlq.url }
output "orders_table_name" { value = aws_dynamodb_table.orders.name }
