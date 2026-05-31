package sentinelpay.policies

required_tags := {"Owner", "Environment", "Service", "CostCenter"}

taggable_types := {
    "aws_vpc", "aws_subnet", "aws_security_group",
    "aws_db_instance", "aws_elasticache_replication_group",
    "aws_s3_bucket", "aws_ecs_cluster", "aws_ecs_service",
    "aws_lb", "aws_iam_role", "aws_lambda_function",
    "aws_cloudwatch_log_group", "aws_kms_key", "aws_ecr_repository"
}

deny contains msg if {
    resource := input.resource_changes[_]
    taggable_types[resource.type]
    resource.change.actions[_] == "create"
    existing_tags := {tag | resource.change.after.tags[tag]}
    missing := required_tags - existing_tags
    count(missing) > 0
    msg := sprintf(
        "POLICY VIOLATION [TAGS]: Resource '%s' (%s) is missing required tags: %v",
        [resource.address, resource.type, missing]
    )
}
