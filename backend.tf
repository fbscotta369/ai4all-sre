terraform {
  backend "s3" {
    bucket         = "ai4all-sre-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    
    # State locking via DynamoDB
    dynamodb_table = "ai4all-sre-tf-lock"
    encrypt        = true
  }
}
