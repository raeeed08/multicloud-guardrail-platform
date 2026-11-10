#!/usr/bin/env bash
# Every guardrail check, in the same order as CI. Requirements: Terraform, Docker, Python 3 with PyYAML
# (or uv, which installs it on the fly).
set -euo pipefail
cd "$(dirname "$0")/.."

# Python 3.11+ with PyYAML: uv provides both on the fly; otherwise use python3 if it is recent enough.
py() {
  if command -v uv >/dev/null; then
    uv run -q --python 3.12 --with pyyaml python "$@"
  elif python3 -c 'import sys, yaml; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
    python3 "$@"
  else
    echo "Need Python 3.11+ with PyYAML (or uv: https://docs.astral.sh/uv/)" >&2
    return 1
  fi
}
step() { printf "\n\033[1m== %s\033[0m\n" "$1"; }

step "1/7 formatting (terraform fmt)"
terraform fmt -check -recursive

step "2/7 rulebook is valid and docs/rules.md is up to date"
py scripts/rulebook.py --check

step "3/7 lint (tflint with AWS and Azure rulesets)"
./scripts/tflint.sh

step "4/7 validate environments + terraform test modules"
./scripts/tf_test.sh

step "5/7 policies catch exactly the insecure fixtures"
py scripts/test_policies.py

step "6/7 the landing zone passes its own rules"
mapfile -t TF_FILES < <(find modules envs -name '*.tf' -not -path '*/.terraform/*')
docker run --rm -v "$PWD":/project -w /project openpolicyagent/conftest:v0.71.1 \
  test --parser hcl2 --all-namespaces -p policies --no-color "${TF_FILES[@]}" | tail -1

step "7/7 Checkov (independent scanner, ~1000 generic checks)"
docker run --rm -v "$PWD":/tf bridgecrew/checkov:3.3.29 -d /tf --framework terraform \
  --skip-path tests/fixtures --compact --quiet

printf "\n\033[1;32mALL CHECKS PASSED\033[0m\n"
