#!/usr/bin/env python3
"""AI-drafted fixes for policy violations, validated by the same guardrails, reviewed by a human.

    python tools/ai_fix.py envs/aws-dev/main.tf          # dry run: print the proposed diff
    python tools/ai_fix.py path/to/file.tf --write       # write the fix into the file
    python tools/ai_fix.py path/to/file.tf --pr          # branch + commit + DRAFT pull request (gh CLI)

Loop:
  1. Conftest finds the violations in the file (same policies as CI).
  2. The LLM receives the file, the violations and the rulebook entries (why + how to fix).
  3. Its answer is UNTRUSTED: it is accepted only if, re-checked by Conftest, the violated rules are gone and no
     new violation appeared, and `terraform fmt` accepts it. Otherwise the model gets one retry with the errors.
  4. A human reviews the diff (or the draft pull request). Nothing is ever applied to a cloud account.

LLM: any OpenAI-compatible endpoint.
  AI_API_KEY (or GROQ_API_KEY), AI_BASE_URL (default Groq), AI_MODEL (default openai/gpt-oss-120b)
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
RULE_ID = re.compile(r"^([A-Z]{2,4}-\d{3})")
FENCE = re.compile(r"```(?:hcl|terraform|tf)?\s*\n(.*?)```", re.S)

Evaluator = Callable[[Path], list[str]]
Completer = Callable[[list[dict[str, str]]], str]

SYSTEM_PROMPT = """You are a senior cloud security engineer fixing Terraform code so it passes security policies.
Rules:
- Return the COMPLETE corrected file in one ```hcl code block, then nothing else.
- Change only what is needed to fix the listed violations. Keep resource names, other attributes and comments.
- Never weaken another control, never remove a resource to make a check pass, never add secrets.
- Add a short comment `# fixed: <RULE-ID>` on the line above each change.
- If a violation cannot be fixed safely inside this file, leave it and explain in an HCL comment why."""


@dataclass
class Proposal:
    path: Path
    original: str
    fixed: str
    violations: list[str]
    remaining: list[str]

    @property
    def diff(self) -> str:
        rel = self.path.relative_to(ROOT) if self.path.is_relative_to(ROOT) else self.path
        return "".join(
            difflib.unified_diff(
                self.original.splitlines(keepends=True),
                self.fixed.splitlines(keepends=True),
                fromfile=f"a/{rel}",
                tofile=f"b/{rel}",
            )
        )


# ---------------------------------------------------------------- guardrails
def conftest_evaluator(path: Path) -> list[str]:
    """Violations of every policy for one file, using the same Conftest image as CI."""
    path = path.resolve()
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copy(path, Path(tmp) / path.name)
        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{ROOT / 'policies'}:/policies:ro",
            "-v",
            f"{tmp}:/project",
            "-w",
            "/project",
            "openpolicyagent/conftest:v0.71.1",
            "test",
            "--parser",
            "hcl2",
            "--all-namespaces",
            "-p",
            "/policies",
            "--output",
            "json",
            path.name,
        ]
        out = subprocess.run(cmd, capture_output=True, text=True, check=False)
    try:
        results = json.loads(out.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"conftest failed: {out.stderr or out.stdout}") from exc
    return sorted(f["msg"] for r in results for f in (r.get("failures") or []))


def terraform_fmt(text: str) -> str | None:
    """Canonical formatting, or None when the text is not valid HCL."""
    if not shutil.which("terraform"):
        return text
    out = subprocess.run(["terraform", "fmt", "-"], input=text, capture_output=True, text=True, check=False)
    return out.stdout if out.returncode == 0 else None


def rule_ids(messages: list[str]) -> set[str]:
    return {m.group(1) for msg in messages if (m := RULE_ID.match(msg))}


# ---------------------------------------------------------------- LLM
def openai_compatible_completer() -> Completer:
    key = os.environ.get("AI_API_KEY") or os.environ.get("GROQ_API_KEY")
    if not key:
        raise SystemExit("Set AI_API_KEY (or GROQ_API_KEY) to use the AI fixer.")
    base = os.environ.get("AI_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
    if not base.startswith("https://"):
        raise SystemExit("AI_BASE_URL must use https:// (the code and its context are sent there).")
    model = os.environ.get("AI_MODEL", "openai/gpt-oss-120b")

    def complete(messages: list[dict[str, str]]) -> str:
        body = json.dumps({"model": model, "messages": messages, "temperature": 0.1, "max_tokens": 8000}).encode()
        req = urllib.request.Request(  # noqa: S310 - scheme checked above (https only)
            f"{base}/chat/completions",
            data=body,
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json", "User-Agent": "ai-fix/1.0"},
        )
        with urllib.request.urlopen(req, timeout=120) as resp:  # noqa: S310 - https only, checked above
            content = json.load(resp)["choices"][0]["message"]["content"] or ""
        return re.sub(r"<think>.*?</think>", "", content, flags=re.S)

    return complete


def build_prompt(path: Path, text: str, violations: list[str], rulebook: dict[str, dict]) -> list[dict[str, str]]:
    guidance = []
    for rid in sorted(rule_ids(violations)):
        rule = rulebook.get(rid, {})
        guidance.append(
            f"{rid} {rule.get('title', '')}\n  why: {' '.join(str(rule.get('why', '')).split())}\n"
            f"  how to fix: {' '.join(str(rule.get('fix_hint', '')).split())}"
        )
    user = (
        f"File: {path.name}\n\nViolations reported by the policies:\n"
        + "\n".join(f"- {v}" for v in violations)
        + "\n\nRulebook guidance:\n"
        + "\n".join(guidance)
        + f"\n\nCurrent file:\n```hcl\n{text}```"
    )
    return [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": user}]


def extract_code(answer: str) -> str | None:
    blocks = FENCE.findall(answer)
    return max(blocks, key=len) if blocks else None


# ---------------------------------------------------------------- the loop
def propose_fix(
    path: Path, complete: Completer, evaluate: Evaluator, rulebook: dict[str, dict], attempts: int = 2
) -> Proposal | None:
    original = path.read_text()
    violations = evaluate(path)
    if not violations:
        return None
    messages = build_prompt(path, original, violations, rulebook)
    target = rule_ids(violations)
    feedback = ""
    for attempt in range(1, attempts + 1):
        answer = complete(messages)
        code = extract_code(answer)
        if code is None:
            feedback = "Your answer had no ```hcl code block with the complete file."
        elif (formatted := terraform_fmt(code)) is None:
            feedback = "The file you returned is not valid HCL (terraform fmt rejected it)."
        else:
            with tempfile.TemporaryDirectory() as tmp:
                candidate = Path(tmp) / path.name
                candidate.write_text(formatted)
                remaining = evaluate(candidate)
            still = target & rule_ids(remaining)
            new = rule_ids(remaining) - rule_ids(violations)
            if not still and not new:
                return Proposal(path, original, formatted, violations, remaining)
            feedback = "The policies still fail:\n" + "\n".join(f"- {m}" for m in remaining)
        print(f"  attempt {attempt} rejected: {feedback.splitlines()[0]}", file=sys.stderr)
        messages = [
            *messages,
            {"role": "assistant", "content": answer},
            {"role": "user", "content": feedback + "\nReturn the complete corrected file again."},
        ]
    return Proposal(path, original, original, violations, violations)  # no acceptable fix


def open_pull_request(proposal: Proposal, rulebook: dict[str, dict]) -> None:
    """Branch, commit and open a DRAFT pull request. CI re-runs every check; a human must approve."""
    status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, cwd=ROOT, check=True)
    if status.stdout.strip():
        raise SystemExit("Working tree is not clean; commit or stash first.")
    ids = sorted(rule_ids(proposal.violations))
    branch = f"ai-fix/{'-'.join(i.lower() for i in ids)}-{proposal.path.stem}"
    rel = str(proposal.path.relative_to(ROOT))
    run("git", "switch", "-c", branch)
    proposal.path.write_text(proposal.fixed)
    run("git", "add", rel)
    run("git", "commit", "-m", f"fix({', '.join(ids)}): AI-drafted remediation in {rel}")
    run("git", "push", "-u", "origin", branch)
    body = "\n".join(
        [
            "## AI-drafted remediation (review required)",
            "",
            *[
                f"- **{i}** {rulebook.get(i, {}).get('title', '')}: {one_line(rulebook.get(i, {}).get('why'))}"
                for i in ids
            ],
            "",
            "Validated before opening: the violated rules are gone, no new violation, `terraform fmt` clean.",
            "CI re-runs every guardrail on this pull request. **Do not merge without reading the diff.**",
            "",
            "Violations fixed:",
            *[f"- `{v}`" for v in proposal.violations],
        ]
    )
    run("gh", "pr", "create", "--draft", "--title", f"fix({', '.join(ids)}): {rel}", "--body", body)


def one_line(text: object) -> str:
    return " ".join(str(text or "").split())


def run(*args: str) -> None:
    subprocess.run(list(args), cwd=ROOT, check=True)


def load_rulebook() -> dict[str, dict]:
    rules = yaml.safe_load((ROOT / "rulebook" / "rules.yaml").read_text())["rules"]
    return {r["id"]: r for r in rules}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("files", nargs="+", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="write the validated fix into the file")
    mode.add_argument("--pr", action="store_true", help="open a draft pull request with the fix")
    args = parser.parse_args(argv)

    rulebook = load_rulebook()
    complete = openai_compatible_completer()
    status = 0
    for file in args.files:
        path = file.resolve()
        if not path.is_relative_to(ROOT) or path.suffix != ".tf":
            print(f"skip {file}: only .tf files inside the repository")
            continue
        print(f"== {path.relative_to(ROOT)}")
        proposal = propose_fix(path, complete, conftest_evaluator, rulebook)
        if proposal is None:
            print("  no violation")
            continue
        if proposal.fixed == proposal.original:
            print("  no acceptable fix found; violations remain:\n  " + "\n  ".join(proposal.violations))
            status = 1
            continue
        print(proposal.diff)
        if args.write:
            path.write_text(proposal.fixed)
            print(f"  written: {path.relative_to(ROOT)} (review it, then commit)")
        elif args.pr:
            open_pull_request(proposal, rulebook)
    return status


if __name__ == "__main__":
    sys.exit(main())
