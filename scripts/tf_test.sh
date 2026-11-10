#!/usr/bin/env bash
# terraform validate for every environment and terraform test for every module (mock providers, no cloud access).
set -euo pipefail
cd "$(dirname "$0")/.."
export TF_IN_AUTOMATION=1
status=0
for dir in envs/*; do
  printf "validate %-34s " "$dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate -no-color | grep -m1 . || status=1
done
for dir in modules/*/*; do
  [ -d "$dir/tests" ] || continue
  printf "test     %-34s " "$dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  if out=$(terraform -chdir="$dir" test -no-color 2>&1); then
    echo "$out" | tail -1
  else
    echo "$out"; status=1
  fi
done
exit $status
