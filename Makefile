.PHONY: init plan apply destroy fmt validate

ENV ?= production

init:
	terraform init

plan:
	terraform plan -var-file=environments/$(ENV).tfvars -out=$(ENV).tfplan

apply:
	terraform apply $(ENV).tfplan

destroy:
	terraform destroy -var-file=environments/$(ENV).tfvars

fmt:
	terraform fmt -recursive

validate:
	terraform validate

# Usage:
#   make plan ENV=staging
#   make apply ENV=staging
#   make plan ENV=production
#   make apply ENV=production
