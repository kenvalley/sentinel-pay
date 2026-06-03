package sentinelpay.policies

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.actions[_] == "create"
    resource.change.after.storage_encrypted == false
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-02]: RDS instance '%s' does not have storage encryption enabled.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.actions[_] == "create"
    resource.change.after.storage_encrypted == true
    not resource.change.after.kms_key_id
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-02]: RDS instance '%s' uses AWS-managed key. A CMK is required.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_elasticache_replication_group"
    resource.change.actions[_] == "create"
    resource.change.after.at_rest_encryption_enabled == false
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-02]: ElastiCache '%s' does not have at-rest encryption enabled.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_elasticache_replication_group"
    resource.change.actions[_] == "create"
    resource.change.after.transit_encryption_enabled == false
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-02]: ElastiCache '%s' does not have in-transit encryption enabled.",
        [resource.address]
    )
}
