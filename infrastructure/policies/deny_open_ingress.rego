package sentinelpay.policies

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    resource.change.actions[_] == "create"
    ingress := resource.change.after.ingress[_]
    ingress.cidr_blocks[_] == "0.0.0.0/0"
    ingress.from_port != 443
    ingress.to_port != 443
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-01]: Security group '%s' allows 0.0.0.0/0 on port %d. Only port 443 is permitted.",
        [resource.address, ingress.from_port]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    resource.change.actions[_] == "create"
    ingress := resource.change.after.ingress[_]
    ingress.ipv6_cidr_blocks[_] == "::/0"
    ingress.from_port != 443
    ingress.to_port != 443
    msg := sprintf(
        "POLICY VIOLATION [V-CLD-01]: Security group '%s' allows ::/0 on port %d.",
        [resource.address, ingress.from_port]
    )
}
