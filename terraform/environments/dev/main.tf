module "secure_s3" {
  source      = "../../modules/s3"
  bucket_name = "cloud-sec-demo-bucket-12345"
  environment = "dev"
  owner       = "shadab"
}

module "security_services" {
  source = "../../modules/security-services"

  project_name  = "cloud-sec"
  config_bucket = module.secure_s3.bucket_id

  alert_email   = var.alert_email 
}
