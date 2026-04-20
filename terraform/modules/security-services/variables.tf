variable "project_name" {}
variable "config_bucket" {}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
}