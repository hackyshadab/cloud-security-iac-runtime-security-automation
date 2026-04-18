package security

deny[msg] {
    resource := input.resource_chnages[_]
    resource.type == "aws_iam_policy"

    contains(resource.change.after.policy, "*:*")
    msg = "IAM policy is too permissive"
    
}