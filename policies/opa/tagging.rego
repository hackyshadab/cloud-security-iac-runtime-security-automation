package security

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"

    not resource.chnage.after.tags.Owner
    msg = "Owner tag is missing on S3 bucket"
}
