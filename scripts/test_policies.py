#!/usr/bin/env python3
"""Prove that every policy catches exactly what it should, and nothing else.

Each fixture in tests/fixtures/<cloud>/ starts with a header listing the rules it tests:

    # rules: NET-001, NET-002

and marks every insecure case with one comment per expected violation:

    # expect: NET-001
    resource "aws_security_group_rule" "ssh_public" { ... }

For the rules listed in the header, the number of violations Conftest reports must equal the number of
`expect` comments: fewer means a missed misconfiguration, more means a false positive on a safe case.
The script also checks that every rule with a `prevent` entry in the rulebook is covered by a fixture,
and runs the Rego unit tests (`conftest verify`).

Conftest runs from the official Docker image unless CONFTEST points to a local binary.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures"
RULE_ID = re.compile(r"\b([A-Z]{2,4}-\d{3})\b")


def conftest(*args: str) -> subprocess.CompletedProcess[str]:
    base = os.environ.get("CONFTEST")
    cmd = (
        shlex.split(base)
        if base
        else [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{ROOT}:/project",
            "-w",
            "/project",
            "openpolicyagent/conftest:v0.71.1",
        ]
    )
    return subprocess.run([*cmd, *args], cwd=ROOT, capture_output=True, text=True, check=False)


def expectations(path: Path) -> tuple[set[str], Counter[str]]:
    text = path.read_text()
    header = re.search(r"^#\s*rules:\s*(.+)$", text, re.M)
    if not header:
        raise SystemExit(f"{path.relative_to(ROOT)}: missing '# rules:' header")
    rules = set(RULE_ID.findall(header.group(1)))
    expected = Counter(m.group(1) for m in re.finditer(r"^\s*#\s*expect:\s*([A-Z]{2,4}-\d{3})", text, re.M))
    unknown = set(expected) - rules
    if unknown:
        raise SystemExit(f"{path.relative_to(ROOT)}: expect {sorted(unknown)} not listed in the rules header")
    return rules, expected


def load_rulebook() -> list[dict]:
    try:
        import yaml  # noqa: PLC0415 - optional dependency, imported only when available
    except ImportError:  # the coverage check is skipped rather than failing on a missing dependency
        print("  (PyYAML not installed: rulebook coverage check skipped)")
        return []
    return yaml.safe_load((ROOT / "rulebook" / "rules.yaml").read_text())["rules"]


def main() -> int:
    failures: list[str] = []

    print("Rego unit tests (conftest verify)")
    verify = conftest("verify", "-p", "policies", "--no-color")
    print("  " + (verify.stdout.strip().splitlines() or ["(no output)"])[-1])
    if verify.returncode != 0:
        failures.append("conftest verify failed:\n" + verify.stdout + verify.stderr)

    files = sorted(FIXTURES.rglob("*.tf"))
    rel = [str(f.relative_to(ROOT)) for f in files]
    run = conftest("test", "--parser", "hcl2", "--all-namespaces", "-p", "policies", "--output", "json", *rel)
    try:
        results = json.loads(run.stdout)
    except json.JSONDecodeError:
        print(run.stdout, run.stderr)
        return 1

    actual: dict[str, Counter[str]] = {r: Counter() for r in rel}
    messages: dict[str, list[str]] = {r: [] for r in rel}
    for result in results:
        for failure in result.get("failures") or []:
            match = RULE_ID.match(failure["msg"])
            if match:
                actual[result["filename"]][match.group(1)] += 1
                messages[result["filename"]].append(failure["msg"])

    print("\nFixtures (expected = caught)")
    covered: dict[str, set[str]] = {"aws": set(), "azure": set()}
    for path, name in zip(files, rel, strict=True):
        rules, expected = expectations(path)
        cloud = path.parent.name
        covered.setdefault(cloud, set()).update(r for r in rules if expected[r] > 0)
        for rule in sorted(rules):
            got, want = actual[name][rule], expected[rule]
            status = "ok " if got == want else "FAIL"
            print(f"  {status} {name:<38} {rule:<8} expected {want}, caught {got}")
            if got != want:
                detail = "\n".join(f"      {m}" for m in messages[name] if m.startswith(rule))
                failures.append(f"{name} {rule}: expected {want}, caught {got}\n{detail}")

    print("\nRulebook coverage")
    for rule in load_rulebook():
        for cloud, spec in (rule.get("prevent") or {}).items():
            policy = ROOT / spec["policy"]
            if not policy.exists():
                failures.append(f"{rule['id']}: policy file {spec['policy']} does not exist")
            elif rule["id"] not in policy.read_text():
                failures.append(f"{rule['id']}: {spec['policy']} never reports this rule")
            if rule["id"] not in covered.get(cloud, set()):
                failures.append(f"{rule['id']}: no {cloud} fixture proves the policy catches it")
            else:
                print(f"  ok  {rule['id']:<8} {cloud:<6} {spec['policy']}")

    if failures:
        print("\nFAILED")
        for f in failures:
            print(" - " + f)
        return 1
    print("\nAll policies catch exactly the insecure cases.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
