terraform {
  backend "s3" {
    bucket         = "mansi-geoip-tf-state"
    key            = "geoip/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
