package sentinelpay.policies

test_deny_unencrypted_rds if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_db_instance.unencrypted",
            "type": "aws_db_instance",
            "change": {
                "actions": ["create"],
                "after": {
                    "storage_encrypted": false,
                    "identifier": "bad-rds",
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_allow_encrypted_rds_with_cmk if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_db_instance.good_rds",
            "type": "aws_db_instance",
            "change": {
                "actions": ["create"],
                "after": {
                    "storage_encrypted": true,
                    "kms_key_id": "arn:aws:kms:eu-west-2:123456789:key/abc-def",
                    "identifier": "good-rds",
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_deny_elasticache_no_at_rest_encryption if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_elasticache_replication_group.bad",
            "type": "aws_elasticache_replication_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "at_rest_encryption_enabled": false,
                    "transit_encryption_enabled": true
                }
            }
        }]
    }
}

test_deny_elasticache_no_transit_encryption if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_elasticache_replication_group.bad_transit",
            "type": "aws_elasticache_replication_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "at_rest_encryption_enabled": true,
                    "transit_encryption_enabled": false
                }
            }
        }]
    }
}
