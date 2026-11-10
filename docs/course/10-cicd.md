# 10: The CI/CD pipelines

## guardrails.yml: every pull request
Parallel jobs, `permissions: contents: read` by default (least privilege), `concurrency` cancels outdated runs.

| Job | Steps | Fails when |
|---|---|---|
| static | `terraform fmt -check`, `rulebook.py --check`, tflint | formatting, rulebook error, stale docs, lint issue |
| terraform | `tf_test.sh` with a provider cache keyed on lock files | invalid env, module test failure |
| policies | `test_policies.py`, Conftest on modules + envs | a policy misses/over-reports, the landing zone violates a rule |
| python | ruff, pytest for the AI fixer | style or test failure |
| checkov | Checkov -> SARIF -> GitHub Security tab (`security-events: write` for this job only) | a failed check |
| secrets | gitleaks over the full history | a secret in Git |

Make these jobs **required status checks** in branch protection: nothing merges to `main` without them.

## deploy.yml: manual, reviewed, secretless
```
workflow_dispatch (stack, plan|apply)
  plan  [environment: dev]       OIDC login -> init (remote state from variables) -> plan -out tfplan
                                 plan in the job summary, tfplan uploaded as an artifact (3 days)
  apply [environment: dev-apply] waits for required reviewers -> downloads the SAME tfplan -> apply
```
Design points:
- `permissions: id-token: write` for OIDC; no cloud secret anywhere, only non-sensitive *variables*.
- `-detailed-exitcode`: 0 = no change, 2 = changes; apply runs only when there are changes.
- `concurrency: deploy-<stack>` and `cancel-in-progress: false`: two runs never touch the same state.
- Applying the saved plan guarantees that what was reviewed is what is applied.

## Supporting tools
- **Dependabot** (`.github/dependabot.yml`): weekly pull requests for action versions and provider versions
  (lock files), grouped; CI validates each.
- **pre-commit** (`.pre-commit-config.yaml`): fmt, gitleaks, rulebook and policy tests before every commit.
- **actionlint**: lints workflows and runs shellcheck on `run:` scripts (`docker run --rm -v $PWD:/repo -w /repo
  rhysd/actionlint`).
- **Makefile** + `scripts/check.sh`: the same checks locally, in the same order.

## Interview questions
1. **How do you deploy Terraform safely from CI?** Plan on PR or on demand, store the plan, require approval in a
   protected environment, apply the saved plan with short-lived OIDC credentials, lock the state, one run at a time.
2. **Why `permissions:` in workflows?** The default token can be broad; limit each job to what it needs.
3. **How do you keep dependencies up to date safely?** Dependabot/Renovate pull requests, pinned versions and lock
   files, CI as the gate.
