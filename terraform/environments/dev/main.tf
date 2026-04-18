module "secure_s3" {
    source = "../../modules/s3"
    bucket_name = "cloud-sec-demo-bucket-12345"
    environment = "dev"
    owner = "shadab"  
}