#!/usr/bin/env python3
"""Validate rulebook/rules.yaml and generate docs/rules.md from it.

python scripts/rulebook.py           # validate + write docs/rules.md
python scripts/rulebook.py --check   # validate + fail if docs/rules.md is out of date (CI)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
RULEBOOK = ROOT / "rulebook" / "rules.yaml"
DOC = ROOT / "docs" / "rules.md"

SEVERITIES = ["critical", "high", "medium", "low"]
CLOUDS = {"aws", "azure"}
REQUIRED = {"id", "title", "severity", "category", "why", "fix_hint"}


def validate(rules: list[dict]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for r in rules:
        rid = r.get("id", "?")
        if missing := REQUIRED - r.keys():
            errors.append(f"{rid}: missing fields {sorted(missing)}")
        if not re.fullmatch(r"[A-Z]{2,4}-\d{3}", rid):
            errors.append(f"{rid}: id must look like NET-001")
        if rid in seen:
            errors.append(f"{rid}: duplicate id")
        seen.add(rid)
        if r.get("severity") not in SEVERITIES:
            errors.append(f"{rid}: severity must be one of {SEVERITIES}")
        if not (r.get("prevent") or r.get("guard")):
            errors.append(f"{rid}: a rule must be enforced somewhere (prevent and/or guard)")
        for cloud, spec in (r.get("prevent") or {}).items():
            if cloud not in CLOUDS:
                errors.append(f"{rid}: unknown cloud {cloud}")
            elif not (ROOT / spec.get("policy", "")).is_file():
                errors.append(f"{rid}: {cloud} policy {spec.get('policy')} not found")
            elif not spec.get("resources"):
                errors.append(f"{rid}: {cloud} policy lists no resources")
    return errors


def render(rules: list[dict]) -> str:
    out = [
        "# Rulebook",
        "",
        "Generated from `rulebook/rules.yaml` by `scripts/rulebook.py`. Do not edit by hand.",
        "",
        (
            "Each rule is enforced at up to three points: **Prevent** (policy on the Terraform code in the pull "
            "request), **Guard** (Azure Policy / AWS SCP in the cloud control plane) and **Detect** (Cloud Copilot "
            "scanning the running account)."
        ),
        "",
        "| ID | Rule | Severity | Prevent (AWS) | Prevent (Azure) | Guard | Detect (Cloud Copilot) |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in rules:
        prevent = r.get("prevent") or {}
        guard = "; ".join(f"{c.upper()}: {g}" for c, g in (r.get("guard") or {}).items()) or "-"
        detect = ", ".join((r.get("detect") or {}).get("copilot", [])) or "-"
        aws, azure = (f"`{Path(prevent[c]['policy']).name}`" if c in prevent else "-" for c in ("aws", "azure"))
        out.append(
            f"| [{r['id']}](#{r['id'].lower()}) | {r['title']} | {r['severity']} | {aws} | {azure} "
            f"| {guard} | {detect} |"
        )
    for r in rules:
        out += ["", f"## {r['id']}", "", f"**{r['title']}** ({r['severity']}, {r['category']})", ""]
        out += [f"*Why:* {r['why'].strip()}", "", f"*Fix:* {r['fix_hint'].strip()}", ""]
        for cloud, spec in (r.get("prevent") or {}).items():
            res = ", ".join(f"`{x}`" for x in spec["resources"])
            out.append(f"- Prevent ({cloud}): `{spec['policy']}` reads {res}")
        for cloud, g in (r.get("guard") or {}).items():
            out.append(f"- Guard ({cloud}): {g}")
        if detect := (r.get("detect") or {}).get("copilot"):
            out.append(f"- Detect: Cloud Copilot {', '.join(detect)}")
        if fw := r.get("frameworks"):
            out.append(
                "- Frameworks: " + "; ".join(f"{k.upper().replace('_', ' ')} {', '.join(v)}" for k, v in fw.items())
            )
    return "\n".join(out) + "\n"


def main() -> int:
    rules = yaml.safe_load(RULEBOOK.read_text())["rules"]
    if errors := validate(rules):
        print("Rulebook errors:\n - " + "\n - ".join(errors))
        return 1
    doc = render(rules)
    if "--check" in sys.argv:
        if not DOC.exists() or DOC.read_text() != doc:
            print("docs/rules.md is out of date: run `make docs`")
            return 1
        print(f"Rulebook OK ({len(rules)} rules), docs/rules.md up to date")
        return 0
    DOC.parent.mkdir(exist_ok=True)
    DOC.write_text(doc)
    print(f"Rulebook OK ({len(rules)} rules), wrote {DOC.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
