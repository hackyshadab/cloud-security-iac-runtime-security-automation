package security

import future.keywords

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_policy"

    policy := resource.change.after.policy

    contains(policy, "*:*")

    msg := sprintf("IAM policy '%s' is too permissive", [resource.name])
}