provider "aws" {
  region = var.region
}

# Zip the Lambda source
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda"
  output_path = "../lambda/geoip_logger.zip"
}

# S3 bucket (for logs if you want to extend later)
resource "aws_s3_bucket" "logs" {
  bucket        = var.s3_bucket_logs
  force_destroy = true
}

# DynamoDB Table to store logs
resource "aws_dynamodb_table" "geoip_logs" {
  name         = var.ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ip"

  attribute {
    name = "ip"
    type = "S"
  }
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_exec" {
  name = "geoip_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Inline policy for Lambda to access DynamoDB and CloudWatch Logs
resource "aws_iam_role_policy" "lambda_inline_policy" {
  name = "geoip-inline-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.geoip_logs.arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "geoip_logger" {
  function_name = var.lambda_function_name
  handler       = "geoip_logger.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.geoip_logs.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_inline_policy
  ]
}

# HTTP API Gateway (v2)
resource "aws_apigatewayv2_api" "api" {
  name          = "geoip-logger-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.api.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.geoip_logger.invoke_arn
  integration_method      = "POST"
  payload_format_version  = "2.0"
}

# Route: GET /log
resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /log"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# $default stage with auto-deploy enabled
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geoip_logger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
