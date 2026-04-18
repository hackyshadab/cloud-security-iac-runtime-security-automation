package security

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"

    not resource.change.after.server_side_encryption_configuration
    msg = "S3 bucket must have encryption enabled"

}