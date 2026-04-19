terraform {
  backend "s3" {
    bucket         = "cloud-sec-terraform-state-unique"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}