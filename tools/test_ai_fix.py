"""Unit tests for the AI fix loop. The LLM and Conftest are replaced by fakes: no network, no Docker.

uv run --with pytest --with pyyaml pytest tools/
"""

from __future__ import annotations

from pathlib import Path

import ai_fix
import pytest

INSECURE = 'resource "aws_kms_key" "data" {\n  description = "data"\n}\n'
FIXED = 'resource "aws_kms_key" "data" {\n  description = "data"\n  # fixed: ENC-002\n  enable_key_rotation = true\n}\n'
RULEBOOK = {
    "ENC-002": {
        "title": "Encryption keys rotate automatically",
        "why": "Limits exposure.",
        "fix_hint": "enable_key_rotation = true",
    }
}


def evaluator(path: Path) -> list[str]:
    """Fake Conftest: the key violates ENC-002 until rotation is enabled; a public ACL violates STO-001."""
    text = path.read_text()
    out = []
    if "aws_kms_key" in text and "enable_key_rotation = true" not in text:
        out.append("ENC-002 [medium]: aws_kms_key.data does not rotate automatically.")
    if "public-read" in text:
        out.append("STO-001 [critical]: aws_s3_bucket_acl.x uses a public ACL.")
    return out


@pytest.fixture
def tf(tmp_path: Path) -> Path:
    path = tmp_path / "main.tf"
    path.write_text(INSECURE)
    return path


@pytest.fixture(autouse=True)
def no_terraform(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(ai_fix, "terraform_fmt", lambda text: text)


def scripted(*answers: str):
    calls: list[list[dict[str, str]]] = []

    def complete(messages: list[dict[str, str]]) -> str:
        calls.append(messages)
        return answers[len(calls) - 1]

    return complete, calls


def test_accepts_a_fix_that_removes_the_violation(tf: Path) -> None:
    complete, calls = scripted(f"Here you go:\n```hcl\n{FIXED}```")
    proposal = ai_fix.propose_fix(tf, complete, evaluator, RULEBOOK)
    assert proposal is not None and proposal.fixed == FIXED
    assert "+  enable_key_rotation = true" in proposal.diff
    assert len(calls) == 1


def test_prompt_carries_violations_and_rulebook_guidance(tf: Path) -> None:
    complete, calls = scripted(f"```hcl\n{FIXED}```")
    ai_fix.propose_fix(tf, complete, evaluator, RULEBOOK)
    user = calls[0][1]["content"]
    assert "ENC-002 [medium]" in user and "enable_key_rotation = true" in user and INSECURE in user


def test_rejects_a_fix_that_introduces_a_new_violation_then_retries(tf: Path) -> None:
    sneaky = FIXED + 'resource "aws_s3_bucket_acl" "x" {\n  acl = "public-read"\n}\n'
    complete, calls = scripted(f"```hcl\n{sneaky}```", f"```hcl\n{FIXED}```")
    proposal = ai_fix.propose_fix(tf, complete, evaluator, RULEBOOK)
    assert proposal is not None and proposal.fixed == FIXED
    assert len(calls) == 2 and "STO-001" in calls[1][-1]["content"]  # the model is told what it broke


def test_gives_up_after_the_retries(tf: Path) -> None:
    complete, _ = scripted("I cannot help with that.", f"```hcl\n{INSECURE}```")
    proposal = ai_fix.propose_fix(tf, complete, evaluator, RULEBOOK)
    assert proposal is not None and proposal.fixed == proposal.original


def test_nothing_to_do_on_a_clean_file(tmp_path: Path) -> None:
    clean = tmp_path / "ok.tf"
    clean.write_text('resource "aws_kms_key" "k" {\n  enable_key_rotation = true\n}\n')
    complete, calls = scripted()
    assert ai_fix.propose_fix(clean, complete, evaluator, RULEBOOK) is None
    assert calls == []


def test_extracts_the_largest_code_block() -> None:
    answer = "```hcl\nsmall\n```\ntext\n```hcl\nmuch larger block\n```"
    assert ai_fix.extract_code(answer) == "much larger block\n"
    assert ai_fix.extract_code("no code") is None
