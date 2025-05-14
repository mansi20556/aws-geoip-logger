variable "region" {
  default = "us-east-1"
}

variable "lambda_function_name" {
  default = "geoip-logger-function"
}

variable "ddb_table_name" {
  default = "geoip_logs"
}

variable "s3_bucket_logs" {
  default = "geoip-logger-logs"
}
