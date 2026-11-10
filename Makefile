.PHONY: help check fmt docs lint test policy conftest checkov ai-fix

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

check: ## Run every check (same as CI)
	./scripts/check.sh

fmt: ## Format all Terraform
	terraform fmt -recursive

docs: ## Regenerate docs/rules.md from the rulebook
	uv run -q --python 3.12 --with pyyaml python scripts/rulebook.py

lint: ## tflint on modules and environments
	./scripts/tflint.sh

test: ## terraform validate (envs) + terraform test (modules)
	./scripts/tf_test.sh

policy: ## Prove the policies catch exactly the insecure fixtures
	uv run -q --python 3.12 --with pyyaml python scripts/test_policies.py

conftest: ## Run the policies on a path: make conftest P=envs/aws-dev
	docker run --rm -v $(PWD):/project -w /project openpolicyagent/conftest:v0.71.1 test --parser hcl2 --all-namespaces -p policies $(P)

checkov: ## Checkov on the real code
	docker run --rm -v $(PWD):/tf bridgecrew/checkov:3.3.29 -d /tf --framework terraform --skip-path tests/fixtures --compact --quiet

ai-fix: ## Draft fixes for policy violations with an LLM (dry run): make ai-fix P=path/to/file.tf
	uv run -q --python 3.12 --with pyyaml python tools/ai_fix.py $(P)
