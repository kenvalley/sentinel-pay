package sentinelpay.policies

test_deny_public_read_acl if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_s3_bucket.bad_bucket",
            "type": "aws_s3_bucket",
            "change": {
                "actions": ["create"],
                "after": {
                    "bucket": "bad-public-bucket",
                    "acl": "public-read",
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_allow_private_acl if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_s3_bucket.good_bucket",
            "type": "aws_s3_bucket",
            "change": {
                "actions": ["create"],
                "after": {
                    "bucket": "good-private-bucket",
                    "acl": "private",
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_deny_block_public_acls_false if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_s3_bucket_public_access_block.bad",
            "type": "aws_s3_bucket_public_access_block",
            "change": {
                "actions": ["create"],
                "after": {
                    "block_public_acls": false,
                    "block_public_policy": true
                }
            }
        }]
    }
}

test_allow_all_blocks_enabled if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_s3_bucket_public_access_block.good",
            "type": "aws_s3_bucket_public_access_block",
            "change": {
                "actions": ["create"],
                "after": {
                    "block_public_acls": true,
                    "block_public_policy": true
                }
            }
        }]
    }
}
