# SentinelPay — Infrastructure

Terraform infrastructure for the SentinelPay payments platform.
Provisioned as part of the VaultBridge Cloud Security Capstone Engagement — Week 2.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.7.0 | https://developer.hashicorp.com/terraform/downloads |
| AWS CLI | >= 2.0 | https://aws.amazon.com/cli/ |
| conftest | >= 0.46 | https://www.conftest.dev |

Authenticate the AWS CLI before running any Terraform command:

```bash
aws configure
# or
aws sso login
```

Verify:
```bash
aws sts get-caller-identity
```

---

## Bootstrap — One-Time Setup

Before running `terraform init`, you must create the S3 state bucket and
DynamoDB lock table manually. Run these commands once:

```bash
# Create state bucket (bucket name must be globally unique)
aws s3api create-bucket \
  --bucket sentinelpay-terraform-state \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

# Enable versioning on state bucket
aws s3api put-bucket-versioning \
  --bucket sentinelpay-terraform-state \
  --versioning-configuration Status=Enabled

# Enable server-side encryption on state bucket
aws s3api put-bucket-encryption \
  --bucket sentinelpay-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access on state bucket
aws s3api put-public-access-block \
  --bucket sentinelpay-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name sentinelpay-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-2
```

---

## Local Configuration

Copy the example vars file and fill in your values:

```bash
cd environments/production
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — set your GitHub username, repo name, and alarm email.
This file is in `.gitignore` and must never be committed.

---

## Developer Workflow

```bash
# 1. Initialise (first time or after provider changes)
make init

# 2. Format all files
make fmt

# 3. Validate syntax
make validate

# 4. Generate plan
make plan

# 5. Run OPA policy checks against the plan (Day 13+)
make policy

# 6. Apply
make apply
```

---

## Module Structure

```
infrastructure/
├── environments/
│   └── production/
│       ├── main.tf           # Root config — calls all modules
│       ├── variables.tf      # All variable definitions
│       ├── outputs.tf        # Root outputs
│       ├── backend.tf        # S3 + DynamoDB state backend
│       ├── versions.tf       # Pinned provider versions
│       └── terraform.tfvars  # Your values — gitignored
├── modules/
│   ├── network/              # Day 9  — VPC, subnets, SGs, Flow Logs
│   ├── identity/             # Day 9  — IAM roles, OIDC, Identity Center
│   ├── data/                 # Day 10 — RDS, ElastiCache, S3, KMS, Secrets Manager
│   ├── compute/              # Day 11 — ECS Fargate, ECR
│   ├── edge/                 # Day 11 — ALB, WAF, ACM cert
│   └── observability/        # Day 12 — GuardDuty, CloudTrail, Security Hub, Config
├── policies/                 # Day 13 — OPA Rego policies
├── Makefile
└── README.md
```

---

## Security Controls by Module

| Module | V-CLD Addressed |
|---|---|
| network | V-CLD-01 (no public RDS), V-CLD-08 (flow logs) |
| identity | V-CLD-04 (no long-lived keys), V-CLD-05 (least-privilege roles) |
| data | V-CLD-02 (S3 encryption), V-CLD-03 (no public ACL) |
| observability | V-CLD-06 (CloudTrail integrity), V-CLD-07 (GuardDuty) |

---

## Important Notes

- **Never run `terraform apply` without a plan file** — always `make plan` first
- **Never commit `terraform.tfvars`** — it contains environment-specific values
- **Never commit `tfplan` or `tfplan.json`** — may contain sensitive output values
- The `terraform.tfstate` file is stored remotely in S3 — never commit local state
