# 11: The AI fix loop (`tools/ai_fix.py`)

## Idea
Finding problems is cheap; fixing them is where teams fall behind. An LLM is good at drafting a small Terraform
change from a precise instruction. It is not trustworthy. So the loop treats its output as untrusted input that
must pass the same guardrails as a human's code.

```
file.tf --Conftest--> violations (RULE-ID messages)
          + rulebook (why, how to fix)  --> LLM (OpenAI-compatible: Groq by default)
          <-- complete corrected file in an hcl block
          --> terraform fmt (valid HCL?)
          --> Conftest again: violated rules gone? no new rule failing?
                 no  -> one retry, telling the model exactly what still fails
                 yes -> diff (default) | --write | --pr (branch, commit, DRAFT pull request via gh)
          --> CI re-runs every check on the pull request --> a human reads and merges
```

## Safety properties (and how they are enforced)
| Risk | Control |
|---|---|
| The model "fixes" by deleting the resource or weakening another control | any new violation is rejected; the prompt forbids it; a human reviews |
| Invalid code | `terraform fmt` must accept it; CI validates |
| Prompt injection from file content | output is only ever a diff/PR, never executed; checks are deterministic |
| Data leaving to a third party | only the file and violation messages are sent; HTTPS-only endpoint enforced; self-hosted models supported via `AI_BASE_URL` |
| Auto-merge | impossible: draft PR, required reviews, required status checks |
| Applying to the cloud | the tool has no cloud credentials and never runs `terraform apply` |

## Tests
`tools/test_ai_fix.py` replaces the LLM and Conftest with fakes:
- a correct fix is accepted, and the diff contains the change;
- the prompt carries the violations and the rulebook guidance;
- a fix that introduces a new violation (a public ACL) is rejected, and the retry message tells the model what
  it broke;
- after the retries, nothing is changed; a clean file makes no LLM call.
It was also run against the **real** Conftest and policies: a first answer that fixed only ENC-002 was rejected
because NET-001 remained; the second was accepted.

## Usage
```bash
export AI_API_KEY=...                                   # or GROQ_API_KEY
python tools/ai_fix.py envs/aws-dev/main.tf             # dry run, prints the diff
python tools/ai_fix.py path.tf --write
python tools/ai_fix.py path.tf --pr                     # needs a clean tree and the gh CLI
AI_BASE_URL=https://my-gateway/v1 AI_MODEL=... python tools/ai_fix.py path.tf
```

## Interview questions
1. **How do you use LLMs safely in infrastructure workflows?** Deterministic validation of every output, least
   privilege (no credentials), human approval, audit trail (pull requests), data minimisation.
2. **Why not let the AI apply fixes automatically?** Infrastructure changes can cause outages and the model can be
   wrong or manipulated; the cost of a review is low compared to the risk.
3. **What is prompt injection here?** Comments in a Terraform file could contain instructions for the model; the
   output is still validated and reviewed, and the tool cannot do anything but propose text.
