variable "project_name" {}
variable "config_bucket" {}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"  # or your desired region
}