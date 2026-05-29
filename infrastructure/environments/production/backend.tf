terraform {
  backend "s3" {
    bucket         = "sentinelpay-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "sentinelpay-terraform-locks"
  }
}
