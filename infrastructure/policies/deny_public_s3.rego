package sentinelpay.policies

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"
    acl := resource.change.after.acl
    acl == "public-read"
    msg := sprintf("POLICY VIOLATION [V-CLD-03]: S3 bucket '%s' has public-read ACL.", [resource.address])
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"
    acl := resource.change.after.acl
    acl == "public-read-write"
    msg := sprintf("POLICY VIOLATION [V-CLD-03]: S3 bucket '%s' has public-read-write ACL.", [resource.address])
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.actions[_] == "create"
    resource.change.after.block_public_acls == false
    msg := sprintf("POLICY VIOLATION [V-CLD-02]: Resource '%s' has block_public_acls=false.", [resource.address])
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.actions[_] == "create"
    resource.change.after.block_public_policy == false
    msg := sprintf("POLICY VIOLATION [V-CLD-02]: Resource '%s' has block_public_policy=false.", [resource.address])
}
