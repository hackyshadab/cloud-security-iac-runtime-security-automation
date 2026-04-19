package security

import future.keywords

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"

    tags := resource.change.after.tags

    not tags.Owner

    msg := sprintf("S3 bucket '%s' missing required 'Owner' tag", [resource.name])
}