#!/usr/bin/env bash
# tflint on every module and environment (not tests/fixtures: those are deliberately incomplete snippets).
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v tflint >/dev/null; then
  TFLINT=(tflint)
else
  TFLINT=(docker run --rm -v "$PWD":/data -v tflint-plugins:/root/.tflint.d -w /data ghcr.io/terraform-linters/tflint:v0.66.0)
fi
"${TFLINT[@]}" --init --config "$PWD/.tflint.hcl" >/dev/null 2>&1 || "${TFLINT[@]}" --init --config /data/.tflint.hcl >/dev/null
cfg=/data/.tflint.hcl; command -v tflint >/dev/null && cfg="$PWD/.tflint.hcl"
status=0
for dir in modules/*/* envs/*; do
  [ -d "$dir" ] || continue
  if ! out=$("${TFLINT[@]}" --chdir="$dir" --config="$cfg" --format compact 2>&1); then
    echo "$out"; status=1
  fi
done
[ $status -eq 0 ] && echo "tflint: no issues in modules/ and envs/"
exit $status
