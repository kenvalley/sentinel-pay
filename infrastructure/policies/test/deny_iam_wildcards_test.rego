package sentinelpay.policies

test_deny_admin_access_policy if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_iam_role_policy.bad_policy",
            "type": "aws_iam_role_policy",
            "change": {
                "actions": ["create"],
                "after": {
                    "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
                }
            }
        }]
    }
}

test_allow_scoped_action if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_iam_role_policy.good_policy",
            "type": "aws_iam_role_policy",
            "change": {
                "actions": ["create"],
                "after": {
                    "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\"],\"Resource\":\"*\"}]}"
                }
            }
        }]
    }
}

test_allow_scoped_resource if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_iam_role_policy.scoped_resource",
            "type": "aws_iam_role_policy",
            "change": {
                "actions": ["create"],
                "after": {
                    "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"arn:aws:s3:::my-bucket/*\"}]}"
                }
            }
        }]
    }
}

test_allow_deny_statement if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_iam_role_policy.deny_policy",
            "type": "aws_iam_role_policy",
            "change": {
                "actions": ["create"],
                "after": {
                    "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
                }
            }
        }]
    }
}
