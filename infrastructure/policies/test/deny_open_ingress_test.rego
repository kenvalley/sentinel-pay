package sentinelpay.policies

test_deny_ssh_open_to_world if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_security_group.bad_sg",
            "type": "aws_security_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "ingress": [{
                        "from_port": 22, "to_port": 22, "protocol": "tcp",
                        "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []
                    }],
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_deny_rds_open_to_world if {
    count(deny) > 0 with input as {
        "resource_changes": [{
            "address": "aws_security_group.bad_rds",
            "type": "aws_security_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "ingress": [{
                        "from_port": 5432, "to_port": 5432, "protocol": "tcp",
                        "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []
                    }],
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_allow_https_from_internet if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_security_group.alb_sg",
            "type": "aws_security_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "ingress": [{
                        "from_port": 443, "to_port": 443, "protocol": "tcp",
                        "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []
                    }],
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}

test_allow_sg_reference_ingress if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "aws_security_group.app_sg",
            "type": "aws_security_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "ingress": [{
                        "from_port": 8001, "to_port": 8001, "protocol": "tcp",
                        "cidr_blocks": [], "ipv6_cidr_blocks": [],
                        "security_groups": ["sg-12345"]
                    }],
                    "tags": {"Owner": "p", "Environment": "p", "Service": "p", "CostCenter": "p"}
                }
            }
        }]
    }
}
