#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "1/5 terraform fmt (is the code tidy?)"
terraform fmt -check -recursive

echo "2/5 terraform validate (does the blueprint make sense?)"
terraform -chdir=envs/dev init -backend=false -input=false >/dev/null
terraform -chdir=envs/dev validate

echo "3/5 policy must PASS on the real code"
# Only real blueprint pages (.tf files), never the hidden .terraform toolbox folder
mapfile -t TF_FILES < <(find modules envs -name '*.tf' -not -path '*/.terraform/*')
docker run --rm -v "$PWD":/project openpolicyagent/conftest test --parser hcl2 --all-namespaces -p policies/azure "${TF_FILES[@]}"

echo "4/5 policy must CATCH the bad fixtures (exactly 3 violations expected)"
out=$(docker run --rm -v "$PWD":/project openpolicyagent/conftest test --parser hcl2 --all-namespaces -p policies/azure --no-color tests/fixtures/azure || true)
echo "$out"
count=$(echo "$out" | grep -c 'FAIL - ' || true)
if [ "$count" -ne 3 ]; then
  echo "Expected 3 violations, got $count"
  exit 1
fi

echo "5/5 Checkov (general inspector) on the real code"
docker run --rm -v "$PWD":/tf bridgecrew/checkov -d /tf --framework terraform --skip-path tests/fixtures --compact --quiet

echo "ALL CHECKS PASSED"
