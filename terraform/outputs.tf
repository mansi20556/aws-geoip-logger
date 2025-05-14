output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "ddb_table" {
  value = aws_dynamodb_table.geoip_logs.name
}
