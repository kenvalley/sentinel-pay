package sentinelpay.policies

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_role_policy"
    resource.change.actions[_] == "create"
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    statement.Effect == "Allow"
    is_wildcard(statement.Action)
    is_wildcard(statement.Resource)
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-05]: IAM role policy '%s' grants wildcard Action on wildcard Resource.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_policy"
    resource.change.actions[_] == "create"
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    statement.Effect == "Allow"
    is_wildcard(statement.Action)
    is_wildcard(statement.Resource)
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-05]: IAM policy '%s' grants wildcard Action on wildcard Resource.",
        [resource.address]
    )
}

is_wildcard(val) if { val == "*" }
is_wildcard(val) if { is_array(val); val[_] == "*" }
