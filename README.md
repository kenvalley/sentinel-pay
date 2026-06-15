# SentinelPay: Production-Grade Secure Cloud Infrastructure and DevSecOps Pipeline on AWS

> A 21-day end-to-end security engineering engagement covering cloud infrastructure hardening, automated DevSecOps pipeline gates, and purple team attack simulation on a pan-African fintech payments platform.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Inherited Baseline](#2-inherited-baseline)
3. [Application Security Fixes](#3-application-security-fixes)
4. [Cloud Infrastructure](#4-cloud-infrastructure)
5. [DevSecOps Pipeline](#5-devsecops-pipeline)
6. [Purple Team Simulation](#6-purple-team-simulation)
7. [Repository Structure](#7-repository-structure)
8. [Running Locally](#8-running-locally)
9. [Deploying Infrastructure](#9-deploying-infrastructure)

---

## 1. Project Overview

SentinelPay Technologies is a fictional pan-African fintech startup providing payment processing, wallet management, and KYC identity verification. This repository represents the output of a 21-day security engineering engagement by SentinelPay's first dedicated security team.

**Engagement structure:**

| Week | Focus | Days | Outcome |
|------|-------|------|---------|
| Week 1 | Application Security | 1-7 | 11 V-APP findings closed |
| Week 2 | Cloud Infrastructure | 8-14 | 8 V-CLD findings closed; full AWS stack deployed |
| Week 3 | DevSecOps and Purple Team | 15-21 | 4 V-PIP findings closed; 7/7 attack scenarios detected or blocked |

**Two microservices:**

| Service | Port | Responsibilities |
|---------|------|-----------------|
| `payments-api` | 8001 | Authentication, accounts, transactions, wallets, webhooks, admin |
| `kyc-api` | 8002 | BVN/NIN identity verification, KYC document management |

---

## 2. Inherited Baseline

The engagement began with a deliberately vulnerable codebase representing a realistic early-stage fintech startup before any security hardening:

**Application layer (11 findings):** SQL injection via string-concatenated queries; broken JWT accepting `alg:none` and HS256; IDOR with no ownership checks; SSRF via unvalidated user-supplied URLs; wallet race condition with no row locking; MD5 password hashing; mass assignment via raw JSON; no rate limiting on auth endpoints; verbose error responses leaking stack traces; `pickle.loads()` deserialisation; no audit logging on money movement.

**Cloud layer (8 findings):** RDS publicly accessible; S3 KYC bucket unencrypted with public ACL; hardcoded AWS access keys in `legacy_deploy.sh`; overbroad IAM role with AdministratorAccess; CloudTrail missing log integrity validation; GuardDuty disabled; no VPC flow logs.

**Pipeline layer (4 findings):** No image signing; no SBOM generation; hardcoded AWS credentials in CI scripts; no branch protection on `main`.

The original vulnerable codebase is preserved on `archive/vulnerable-baseline` for reference.

---

## 3. Application Security Fixes

All 11 V-APP findings were remediated across two branches and merged by Day 7. This section is summarised briefly as the primary focus of this engagement is cloud infrastructure and pipeline automation.

**Critical path fixes (branch: `fix/day5-critical-path`):**
- V-APP-01: Parameterised queries replacing all string-concatenated SQL
- V-APP-02: RS256 with mandatory algorithm enforcement; `alg:none` rejected at decode
- V-APP-03: `@require_ownership` decorator on all resource endpoints
- V-APP-05: `SELECT FOR UPDATE` within explicit transaction block
- V-APP-10: `pickle` removed; replaced with `json.loads()` and jsonschema validation

**Defence in depth fixes (branch: `fix/day6-defence-in-depth`):**
- V-APP-04: `validate_callback_url()` guard blocking RFC1918 and 169.254.0.0/16 (AWS metadata)
- V-APP-06: Argon2id replacing MD5 (`time_cost=2`, `memory_cost=65536`, `parallelism=2`)
- V-APP-07: Pydantic schemas with explicit field allowlists on all request bodies
- V-APP-08: `flask-limiter` with Redis backend; 5 req/min on login, 3 req/min on register
- V-APP-09: Global exception handler returning opaque `{"error": "...", "error_id": "XXXX"}` only
- V-APP-11: Structured `emit_audit_event()` on all money-movement and authentication operations

---

## 4. Cloud Infrastructure

All infrastructure is written in Terraform and lives in `infrastructure/`. State is stored remotely in S3 with DynamoDB locking. Six modules are composed in `infrastructure/environments/production/main.tf`.

**Branch:** `feat/week2-cloud-foundation`

### 4.1 State Backend

```hcl
terraform {
  backend "s3" {
    bucket         = "sentinelpay-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "sentinelpay-terraform-locks"
    encrypt        = true
  }
}
```

Remote state is encrypted at rest, versioned, and locked during applies to prevent concurrent modifications.

### 4.2 Network Module

```
VPC: 10.0.0.0/16 (eu-west-2)

├── eu-west-2a
│   ├── Public subnet:        10.0.1.0/24   (ALB, NAT Gateway)
│   ├── Private app subnet:   10.0.10.0/24  (ECS tasks)
│   └── Private data subnet:  10.0.20.0/24  (RDS, ElastiCache)
│
└── eu-west-2b
    ├── Public subnet:        10.0.2.0/24
    ├── Private app subnet:   10.0.11.0/24
    └── Private data subnet:  10.0.21.0/24
```

**Security groups (least privilege, scoped by reference not CIDR):**

| Security Group | Inbound Rule | Closes |
|---------------|-------------|--------|
| `alb-sg` | 0.0.0.0/0:443, 0.0.0.0/0:80 | Public entry point |
| `payments-api-sg` | alb-sg:8001 only | V-CLD-01 |
| `kyc-api-sg` | alb-sg:8002, payments-api-sg:8002 | V-CLD-01 |
| `rds-sg` | payments-api-sg:5432, kyc-api-sg:5432 | V-CLD-01 |
| `elasticache-sg` | payments-api-sg:6379, kyc-api-sg:6379 | V-CLD-01 |

No security group has `0.0.0.0/0` on any data plane port. VPC Flow Logs capture ALL traffic to CloudWatch.

### 4.3 Identity Module

**ECS roles (separation of execution and task roles):**

The most critical IAM design decision in the engagement. Two completely separate roles per service:

- **Execution role:** Used by the ECS agent before the container starts. Needs `AmazonECSTaskExecutionRolePolicy` plus `secretsmanager:GetSecretValue`. Injecting secrets at startup requires this role, not the task role.
- **Task role:** Used by application code inside the running container. Scoped to only what the application calls at runtime (S3, CloudWatch Logs).

Using the same role for both is a common misconfiguration that causes `ResourceInitializationError` on ECS task startup.

| Role | Principal | Permissions |
|------|-----------|-------------|
| `payments-api-execution-role` | ECS agent | ECR pull, Secrets Manager read, CloudWatch Logs |
| `payments-api-task-role` | Application code | CloudWatch Logs only |
| `kyc-api-execution-role` | ECS agent | ECR pull, Secrets Manager read, CloudWatch Logs |
| `kyc-api-task-role` | Application code | S3 KYC bucket read/write, CloudWatch Logs |
| `github-actions-deploy-role` | GitHub Actions OIDC | ECR push, ECS register task def, ECS update service |

**GitHub Actions OIDC (closes V-CLD-04):**

```hcl
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

OIDC eliminates long-lived AWS access keys entirely. GitHub Actions assumes the deploy role via Web Identity Token. No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` stored anywhere.

### 4.4 Data Module

**KMS Customer Managed Keys (4 separate CMKs):**

| Key Alias | Encrypts | Why Separate |
|-----------|----------|-------------|
| `sentinelpay-production-rds` | RDS PostgreSQL storage | Isolates database encryption domain |
| `sentinelpay-production-s3-kyc` | KYC documents S3 bucket | Isolates PII document encryption |
| `sentinelpay-production-s3-audit` | Audit logs bucket, Secrets Manager secrets | Isolates compliance log encryption |
| `sentinelpay-production-elasticache` | ElastiCache Redis at rest | Isolates cache encryption domain |

Separate keys mean a compromise or rotation of one key affects only that data store, not everything.

**RDS PostgreSQL:**
- Multi-AZ deployment across eu-west-2a and eu-west-2b
- Encrypted at rest with KMS CMK
- `rds.force_ssl = 1` enforces TLS on all connections
- `publicly_accessible = false`; accessible only from app tier security groups on port 5432
- 7-day automated backups; deletion protection enabled

**ElastiCache Redis 7:**
- Transit encryption enabled; at-rest encryption with KMS CMK
- AUTH token stored in Secrets Manager; never in environment variables
- 2-node replication group with automatic failover

**S3 Buckets:**

| Bucket | Purpose | Controls |
|--------|---------|---------|
| `sentinelpay-production-kyc-documents` | KYC identity documents | SSE-KMS, Object Lock Governance 90 days, versioning, SSL-only policy, block all public access |
| `sentinelpay-production-audit-logs-2` | CloudTrail, ALB access logs | SSE-KMS, Object Lock Compliance 365 days, Glacier after 365 days |

**Secrets Manager:** All runtime secrets (DB password, Redis AUTH token, JWT private key, JWT public key) stored in Secrets Manager. Injected into containers at startup by the execution role. Never stored in environment variables or Terraform state.

### 4.5 Compute Module

**ECR Repositories:**
- `IMMUTABLE` image tags; once pushed a tag cannot be overwritten
- Scan on push enabled; images scanned for CVEs on every push
- KMS encryption; lifecycle policy retaining last 10 images

**ECS Fargate Task Definitions:**
- Non-root user: UID 1001 (`appuser`) on both services
- All Linux capabilities dropped (`linuxParameters.capabilities.drop = ["ALL"]`)
- Separate `execution_role_arn` and `task_role_arn` on every task definition
- Secrets injected at container startup via execution role from Secrets Manager
- CloudWatch log groups with 30-day retention
- Deployment circuit breaker with automatic rollback on failure

**ECS Services:**
- 2 tasks per service across 2 AZs for high availability
- `lifecycle { ignore_changes = [task_definition] }` allows the CD pipeline to manage task definition updates without Terraform conflicts

### 4.6 Edge Module

**ALB:**
- HTTP listener (port 80) returns 301 redirect to HTTPS
- HTTPS listener (port 443) with TLS termination
- Deletion protection enabled
- Routing: `/v1/auth/*`, `/v1/accounts/*`, `/v1/transactions/*`, `/v1/wallets/*` to payments-api; `/v1/verify/*`, `/v1/documents/*`, `/v1/kyc/*` to kyc-api

**WAF:**

| Rule | Type | Action |
|------|------|--------|
| `AWSManagedRulesCommonRuleSet` | Managed | Block |
| `AWSManagedRulesSQLiRuleSet` | Managed | Block |
| `AWSManagedRulesKnownBadInputsRuleSet` | Managed | Block |
| `PaymentsRateLimit` | Custom | Block after 100 req/5 min per IP |

WAF logs to CloudWatch (`aws-waf-logs-sentinelpay-production`).

### 4.7 Observability Module

**GuardDuty:**
- S3 protection, Kubernetes audit log protection, and malware scanning all enabled
- HIGH severity findings (score >= 7.0) trigger EventBridge rule, which invokes a containment Lambda that attaches a deny-all policy to the compromised principal and publishes a P0 alert to SNS

**CloudTrail:**
- Multi-region trail capturing all API calls
- `enable_log_file_validation = true`; SHA-256 digest files detect any log tampering
- KMS-encrypted; logs delivered to Object Lock Compliance bucket (365-day retention)

**Security Hub:**
- AWS Foundational Security Best Practices (FSBP) standard enabled
- CIS Benchmark v1.4.0 standard enabled
- Hundreds of AWS Config rules automatically created and enforced

**AWS Config:**
- Records all supported resource types including global resources
- CIS conformance pack enforces `restricted-ssh` and `vpc-sg-restricted-common-ports` rules
- Delivers to separate `sentinelpay-production-config-logs` bucket

**Honeytoken:**
- Decoy IAM user (`sentinelpay/decoy/sentinelpay-production-honeytoken-user`) with deny-all policy
- Credentials stored in Secrets Manager as `sentinelpay-production/decoy/legacy-credentials`
- Any API call using the credentials fires a CloudWatch alarm within 60 seconds

**Root account alarm:** Any root API call triggers an immediate SNS alert to the security team.

### 4.8 OPA Policy Pack

Five Rego policies enforced at Terraform plan time via conftest. Any plan violating these policies blocks the PR before `terraform apply` is ever called.

| Policy | Blocks | V-ID |
|--------|--------|------|
| `deny_public_s3` | Public ACLs or disabled public access blocks on S3 | V-CLD-02/03 |
| `deny_open_ingress` | `0.0.0.0/0` ingress on any port except 443 | V-CLD-01 |
| `require_encryption` | Unencrypted RDS, ElastiCache, or S3 resources | V-CLD-02 |
| `deny_iam_wildcards` | IAM policies with `Action: *` AND `Resource: *` | V-CLD-05 |
| `require_tags` | Resources missing Owner, Environment, Service, or CostCenter tags | Operational |

**Test results:** 20/20 unit tests passing (`conftest verify --policy infrastructure/policies/`).

---

## 5. DevSecOps Pipeline

All pipeline configuration lives in `.github/workflows/`. Six workflow files compose the full CI/CD gate.

**Branch:** `feat/week3-devsecops` (merged to `main`)

### 5.1 Workflow Overview

| File | Trigger | Purpose | Mode |
|------|---------|---------|------|
| `ci-pr-gate.yml` | Every PR | Orchestrator; calls all scan workflows | Blocking |
| `ci-code-scan.yml` | Via gate | Gitleaks, Bandit, Semgrep, Trivy SCA | Blocking |
| `ci-iac-scan.yml` | Via gate | Checkov, tfsec, OPA/conftest | Mixed |
| `ci-container-scan.yml` | Via gate | Trivy image, Cosign signing, Syft SBOM | Blocking |
| `ci-dast.yml` | Via gate | OWASP ZAP baseline scan | Blocking |
| `cd-deploy.yml` | Push to `main` | Build, push, register task def, deploy to ECS | Deploy |

### 5.2 Code and Dependency Gate (`ci-code-scan.yml`)

**Gitleaks v8.18.2** (pinned binary download):
- Scans every PR for secrets and credentials
- `.gitleaksignore` suppresses documented baseline findings using specific fingerprints
- Blocks PR on any new secret detection

**Bandit:**
- Python security pattern scanning at medium severity and confidence thresholds
- `.bandit` config suppresses confirmed false positives from the Day 3 triage
- Blocks PR on HIGH or CRITICAL findings

**Semgrep:**
- Standard `p/python` and `p/flask` packs for known vulnerability patterns
- Five custom regression rules in `.github/semgrep/regression-rules.yml`:

| Rule | Detects | Guards |
|------|---------|--------|
| `no-raw-sql-queries` | `f"SELECT...{var}"` string concatenation | V-APP-01 fix |
| `no-alg-none-jwt` | `algorithms=["none"]` or missing algorithm param | V-APP-02 fix |
| `no-unvalidated-urls` | `requests.get(url)` without `validate_callback_url()` | V-APP-04 fix |
| `no-md5-password-hash` | `hashlib.md5(password)` | V-APP-06 fix |
| `no-pickle-loads` | `pickle.loads()` anywhere in services/ | V-APP-10 fix |

If any Week 1 fix is accidentally reverted, the corresponding Semgrep rule fires and blocks the PR.

**Trivy SCA:**
- Scans `requirements.txt` for both services against the CVE database
- Blocks on CRITICAL CVEs only; HIGH is informational

### 5.3 IaC and Container Gate (`ci-iac-scan.yml` and `ci-container-scan.yml`)

**Checkov:**
- Full Terraform scan in soft-fail (informational) mode
- Known acceptable deviations suppressed via `--skip-check`
- Findings visible in PR but do not block merge

**tfsec:**
- Second IaC scanner for defence in depth; different rule set from Checkov
- Informational mode

**OPA/conftest (BLOCKING):**
- The five custom Rego policies from `infrastructure/policies/` run against the Terraform plan JSON
- Any violation blocks the PR; Checkov and tfsec are informational, OPA is the enforcement layer

**Trivy image scan (BLOCKING):**
- Scans built container images for CRITICAL unfixed CVEs
- `--ignore-unfixed` avoids blocking on CVEs where no upstream patch exists yet

**Cosign keyless signing (closes V-PIP-01):**

```bash
cosign sign --yes \
  --rekor-url https://rekor.sigstore.dev \
  ${ECR_REGISTRY}/${SERVICE_REPO}:${IMAGE_TAG}
```

Every built image is signed using the GitHub Actions OIDC identity via the Sigstore/Rekor transparency log. No keys to manage. Anyone can verify the image was built by this pipeline and has not been modified since.

**Syft SBOM generation (closes V-PIP-02):**

```bash
syft ${ECR_REGISTRY}/${SERVICE_REPO}:${IMAGE_TAG} \
  --output cyclonedx-json \
  --file sbom-${SERVICE}.json
```

A CycloneDX Software Bill of Materials is generated for every built image listing every OS package and Python library with versions. Attached as a workflow artefact on every pipeline run. Used for rapid CVE triage when a new vulnerability is disclosed.

### 5.4 DAST Gate (`ci-dast.yml`)

OWASP ZAP baseline scan runs against a live ephemeral instance of both services spun up inside the GitHub Actions runner via docker compose:

```bash
docker run --user root --network host \
  -v /tmp/zap:/zap/wrk/:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://localhost:8001 \
    -c /zap/wrk/rules.tsv \
    -r zap-report.html \
    -J zap-report.json
```

Alert suppressions in `.github/zap/rules.tsv` cover controls handled at the ALB layer (HSTS, CSP, Permissions-Policy). HIGH risk alerts not in the suppression list block the PR.

### 5.5 CD Pipeline (`cd-deploy.yml`)

The deployment pipeline authenticates to AWS via OIDC (closes V-PIP-03) and follows a four-step deploy pattern that ensures ECS actually runs the new image:

```
1. Build image and push with git SHA tag to ECR
2. Fetch current task definition JSON from ECS
3. Swap image URI to new tag; strip read-only fields; register new task definition revision
4. Update ECS service to use the new task definition revision
5. Wait for services-stable
```

The critical step is 3 and 4. A naive `--force-new-deployment` only restarts tasks with the existing task definition; it does not deploy the new image. Explicitly registering a new revision and pointing the service at it is the correct pattern.

### 5.6 Branch Protection

GitHub branch protection rules on `main`:
- Pull request required before merging
- Minimum 1 approving review
- All CI status checks must pass before merge is permitted
- No force pushes; no branch deletion
- Admins are not exempt

---

## 6. Purple Team Simulation

Seven attack scenarios were executed against the deployed production environment on Days 19 and 20. The team played both attacker and defender simultaneously.

**Environment at time of simulation:**
- Both ECS services: 2/2 Running, revision 12, Deployment: Success
- ALB health check: `{"service":"payments-api","status":"ok"}`

### 6.1 Results

| # | Scenario | Attack | Detection Mechanism | MTTD | Result |
|---|---------|--------|-------------------|------|--------|
| 1 | Leaked credentials | Commit fake AWS key to branch, open PR | Gitleaks CI gate | < 60s | BLOCKED |
| 2 | Malicious dependency | Add `requests==2.3.0` (known CVE) to requirements.txt | Trivy SCA CI gate | < 60s | BLOCKED |
| 3 | IaC drift | Open RDS SG to `0.0.0.0/0:5432` via AWS Console | AWS Config NON_COMPLIANT | ~30 min | DETECTED |
| 4 | IDOR replay | Cross-user resource access with valid JWT | `@require_ownership` decorator + HTTP 403 | Instant | BLOCKED |
| 5 | SQLi WAF bypass | `1'OR'1'='1` payload to ALB endpoint | WAF AWSManagedRulesSQLiRuleSet | Instant | BLOCKED |
| 6 | Runtime task compromise | ECS Exec shell into running Fargate task | ECS Exec disabled; SessionManagerPlugin not found | Instant | BLOCKED |
| 7 | Honeytoken trip | Retrieve and use decoy credentials from Secrets Manager | CloudWatch alarm | < 60s | DETECTED |

**Final score: 7/7 scenarios detected or blocked. 5 blocked immediately, 2 detected within SLA.**

### 6.2 Scenario Notes

**Scenario 3 (IaC Drift):** The AWS Console change bypassed Terraform entirely. AWS Config's `securityhub-vpc-sg-restricted-common-ports` rule flagged the RDS security group as NON_COMPLIANT. Remediation was a single `revoke-security-group-ingress` call; `terraform plan` afterwards confirmed No changes.

**Scenario 7 (Honeytoken):** The decoy ARN `arn:aws:iam::584299187762:user/sentinelpay/decoy/sentinelpay-production-honeytoken-user` was confirmed via `sts:GetCallerIdentity`. The CloudWatch alarm `sentinelpay-production-honeytoken-used` fired within 60 seconds. Note: AWS environment variables must be cleared after the test or subsequent CLI calls will use the honeytoken identity and fail with `AccessDeniedException`.

---

## 7. Repository Structure

```
sentinel-pay/
├── services/
│   ├── payments-api/                   # Flask app; auth, transactions, wallets, webhooks
│   │   ├── app/
│   │   │   ├── routes/                 # Blueprints; auth, accounts, transactions, wallets
│   │   │   ├── auth.py                 # RS256 JWT encode/decode; Argon2id hashing
│   │   │   ├── audit.py                # Structured audit event emitter
│   │   │   ├── limiter.py              # flask-limiter instance; avoids circular import
│   │   │   ├── security.py             # validate_callback_url(); SSRF guard
│   │   │   └── main.py                 # App factory; error handlers; blueprint registration
│   │   ├── tests/
│   │   ├── Dockerfile                  # Non-root UID 1001; python:3.11-slim; /app/tmp
│   │   └── requirements.txt
│   │
│   └── kyc-api/                        # Flask app; BVN/NIN verification, KYC documents
│       ├── app/
│       │   ├── routes/                 # Blueprints; verify, documents
│       │   ├── auth.py                 # RS256 JWT decode; shared with payments-api pattern
│       │   ├── security.py             # validate_callback_url(); SSRF guard
│       │   └── main.py
│       ├── tests/
│       ├── Dockerfile
│       └── requirements.txt
│
├── infrastructure/
│   ├── environments/
│   │   └── production/
│   │       ├── main.tf                 # Root module; wires all six child modules
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── backend.tf              # S3 + DynamoDB remote state; eu-west-2
│   │       └── versions.tf             # Terraform >= 1.5.0; AWS provider ~> 5.0
│   ├── modules/
│   │   ├── network/                    # VPC, subnets, SGs, NAT gateways, flow logs
│   │   ├── identity/                   # IAM execution + task roles, OIDC provider
│   │   ├── data/                       # KMS CMKs, RDS, ElastiCache, S3, Secrets Manager
│   │   ├── edge/                       # ALB, WAF, target groups, listeners
│   │   ├── compute/                    # ECR, ECS cluster, task definitions, services
│   │   └── observability/              # GuardDuty, CloudTrail, Security Hub, Config, honeytoken
│   └── policies/                       # OPA Rego policies; 5 policies, 20 unit tests
│
├── .github/
│   ├── workflows/
│   │   ├── ci-pr-gate.yml              # Orchestrator; calls all scan workflows on every PR
│   │   ├── ci-code-scan.yml            # Gitleaks, Bandit, Semgrep, Trivy SCA
│   │   ├── ci-iac-scan.yml             # Checkov, tfsec, OPA/conftest
│   │   ├── ci-container-scan.yml       # Trivy image, Cosign signing, Syft SBOM
│   │   ├── ci-dast.yml                 # OWASP ZAP baseline scan
│   │   └── cd-deploy.yml               # OIDC deploy; register task def; update ECS service
│   ├── semgrep/
│   │   └── regression-rules.yml        # 5 custom rules guarding Week 1 fixes
│   └── zap/
│       └── rules.tsv                   # ZAP alert suppressions for ALB-handled controls
│
├── seed/
│   └── init.sql                        # Database schema and seed data
│
├── docs/
│   ├── week1/                          # DAY1-7.md + TROUBLESHOOTING.md
│   ├── week2/                          # DAY8-14.md + TROUBLESHOOTING.md
│   └── week3/                          # DAY15-21.md + TROUBLESHOOTING.md
│
├── docker-compose.yml                  # Local dev; PostgreSQL 15, Redis 7, both APIs
├── .bandit                             # Bandit false positive suppressions
├── .gitleaks.toml                      # Gitleaks config; excludes .gitleaksignore from scan
├── .gitleaksignore                     # Known baseline secret fingerprints
├── .trivyignore                        # Trivy CVE suppressions
└── README.md
```

---

## 8. Running Locally

**Prerequisites:** Docker Desktop, Python 3.11, git

```bash
# Clone
git clone https://github.com/kenvalley/sentinel-pay.git
cd sentinel-pay

# Start all services
docker compose up --build

# Verify both services are healthy
curl http://localhost:8001/health
# {"service":"payments-api","status":"ok"}

curl http://localhost:8002/health
# {"service":"kyc-api","status":"ok"}
```

The docker-compose stack starts: PostgreSQL 15, Redis 7, payments-api, kyc-api. The database is seeded automatically from `seed/init.sql` on first run.

**Run tests:**

```bash
# payments-api
cd services/payments-api
pip install -r requirements.txt
pytest tests/ -v

# kyc-api
cd services/kyc-api
pip install -r requirements.txt
pytest tests/ -v
```

---

## 9. Deploying Infrastructure

**Prerequisites:** Terraform >= 1.5.0, AWS CLI configured for `eu-west-2`, conftest v0.68.2

```bash
cd infrastructure/environments/production

# Initialise remote state
terraform init

# Validate and run OPA policy checks
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
conftest test --policy ../../policies/ plan.json

# Apply in module order (first time only; subsequent applies can run without -target)
terraform apply -target=module.network -auto-approve
terraform apply -target=module.identity -auto-approve
terraform apply -target=module.data -auto-approve
terraform apply -target=module.edge -auto-approve
terraform apply -target=module.compute -auto-approve
terraform apply -target=module.observability -auto-approve
```

**After applying the data module**, populate the JWT key secrets before deploying compute:

```bash
aws secretsmanager put-secret-value \
  --secret-id "sentinelpay-production/payments-api/jwt-private-key" \
  --secret-string file://jwt_private.pem \
  --region eu-west-2

aws secretsmanager put-secret-value \
  --secret-id "sentinelpay-production/payments-api/jwt-public-key" \
  --secret-string file://jwt_public.pem \
  --region eu-west-2
```

**GitHub Actions variables required:**

```
AWS_REGION              = eu-west-2
PAYMENTS_API_ECR_REPO   = sentinelpay-production/payments-api
KYC_API_ECR_REPO        = sentinelpay-production/kyc-api
ECS_CLUSTER             = sentinelpay-production-cluster
PAYMENTS_API_SERVICE    = sentinelpay-production-payments-api
KYC_API_SERVICE         = sentinelpay-production-kyc-api
```

**GitHub Actions secret required:**

```
AWS_ROLE_ARN = arn:aws:iam::<ACCOUNT_ID>:role/sentinelpay-production-github-actions-deploy-role
```

**Teardown:**

```bash
# Disable RDS deletion protection first
aws rds modify-db-instance \
  --db-instance-identifier sentinelpay-production-postgres \
  --no-deletion-protection --apply-immediately --region eu-west-2

# Destroy in reverse order
terraform destroy -target=module.observability -auto-approve
terraform destroy -target=module.compute -auto-approve
terraform destroy -target=module.edge -auto-approve
terraform destroy -target=module.data -auto-approve
terraform destroy -target=module.identity -auto-approve
terraform destroy -target=module.network -auto-approve
```

---

## Key Tool Versions

| Tool | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider | ~> 5.0 |
| conftest | 0.68.2 |
| OPA | 1.15.2 |
| Gitleaks | 8.18.2 |
| Bandit | 1.7.8 |
| Semgrep | 1.75.0 |
| Trivy | 0.71.0 |
| Python | 3.11 |
| gunicorn | 20.1.0 |

---

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | All weeks merged; CD pipeline deploys from here |
| `archive/vulnerable-baseline` | Original vulnerable codebase preserved for reference |
| `fix/day5-critical-path` | Week 1 critical fixes (merged) |
| `fix/day6-defence-in-depth` | Week 1 defence in depth fixes (merged) |
| `feat/week2-cloud-foundation` | Terraform infrastructure (merged) |
| `feat/week3-devsecops` | DevSecOps pipeline (merged) |

---

*Author: Kenneth Ikeagu*

---

*Contact: kenvalleytech@gmail.com*
