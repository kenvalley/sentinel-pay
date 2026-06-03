terraform {
  backend "s3" {
    # These values cannot use variables — they must be literals.
    # Replace the bucket name with the one you create in the bootstrap step.
    # See README.md — "Bootstrap" section for the exact aws cli commands.
    bucket         = "sentinelpay-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "sentinelpay-terraform-locks"
  }
}
