package sentinelpay.policies

test_deny_missing_owner_tag if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_vpc.missing_tag",
            "type": "aws_vpc",
            "change": {
                "actions": ["create"],
                "after": {
                    "cidr_block": "10.0.0.0/16",
                    "tags": {"Environment": "production", "Service": "sentinelpay", "CostCenter": "engineering"}
                }
            }
        }]
    }
}

test_deny_no_tags if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_s3_bucket.no_tags",
            "type": "aws_s3_bucket",
            "change": {
                "actions": ["create"],
                "after": {"bucket": "no-tags-bucket", "tags": {}}
            }
        }]
    }
}

test_allow_all_required_tags if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_vpc.fully_tagged",
            "type": "aws_vpc",
            "change": {
                "actions": ["create"],
                "after": {
                    "cidr_block": "10.0.0.0/16",
                    "tags": {"Owner": "platform", "Environment": "production", "Service": "sentinelpay", "CostCenter": "engineering"}
                }
            }
        }]
    }
}

test_allow_non_taggable_resource if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_route_table_association.rta",
            "type": "aws_route_table_association",
            "change": {
                "actions": ["create"],
                "after": {"subnet_id": "subnet-123", "route_table_id": "rtb-456"}
            }
        }]
    }
}
