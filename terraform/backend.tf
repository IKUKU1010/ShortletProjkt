terraform {
  backend "s3" {
    bucket         = "shortlet-bucket"
    key            = "terraform/key"
    region         = "us-east-1"
    dynamodb_table = "shortlet-lock"
  }
}