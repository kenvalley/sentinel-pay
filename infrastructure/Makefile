TERRAFORM_DIR := environments/production

.PHONY: init validate fmt plan apply destroy clean policy test-policy

## init: Initialise Terraform with remote state backend
init:
	cd $(TERRAFORM_DIR) && terraform init

## validate: Validate Terraform configuration syntax
validate:
	cd $(TERRAFORM_DIR) && terraform validate

## fmt: Format all Terraform files
fmt:
	terraform fmt -recursive

## plan: Generate and show Terraform execution plan
plan:
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

## plan-json: Generate plan as JSON for OPA policy checks
plan-json:
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan && terraform show -json tfplan > tfplan.json

## test-policy: Run OPA unit tests against all policies
test-policy:
	conftest test policies/test/ --policy policies/ --namespace sentinelpay.policies

## policy: Run OPA policy checks against the current Terraform plan
policy: plan-json
	conftest verify --policy policies/ --namespace sentinelpay.policies
	conftest test --policy policies/ $(TERRAFORM_DIR)/tfplan.json --namespace sentinelpay.policies

## apply: Apply the Terraform plan
apply:
	cd $(TERRAFORM_DIR) && terraform apply tfplan

## apply-auto: Apply without interactive approval (CI use only)
apply-auto:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

## destroy: Destroy all resources (use with caution)
destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

## clean: Remove local Terraform artefacts
clean:
	find . -name "tfplan" -delete
	find . -name "tfplan.json" -delete

## help: Show this help message
help:
	@grep -E '^##' Makefile | sed 's/## //'
