# Multi-Cloud Guardrail Platform

![guardrails](https://github.com/raeeed08/multicloud-guardrail-platform/actions/workflows/guardrails.yml/badge.svg)

A security-first cloud platform built with Terraform, where **one rulebook is enforced twice**: before deployment (in the pipeline) and after deployment (by a runtime scanner). Fixes are proposed by AI, but a human always approves.

## The idea

Most projects either block bad infrastructure before it is built, or scan it afterwards. This project does both from the same rulebook, and closes the loop:

    rulebook (one rule ID, one explanation)
        |
        |-- PREVENT (pipeline): Checkov + custom Conftest/Rego policies block a bad pull request
        |
        '-- DETECT (runtime): a scanner checks the live cloud with the same rule IDs
                |
                v
        AI drafts a Terraform fix -> automatic validation -> pull request
        -> human review and merge -> deploy -> re-scan proves it is fixed

## Status (honest)

| Part | Status |
|---|---|
| Azure network module (VNet, subnets, NSGs, default deny) | Done, validated |
| Rule NET-001 (no SSH/RDP open to the internet) with Azure policy | Done, tested (3 bad cases caught, 1 safe case allowed) |
| One-command check script | Done |
| CI pipeline (GitHub Actions) | Done, runs on every pull request |
| AWS equivalents of the rules and modules | Planned |
| Runtime scanner connection | Planned |
| AI-drafted fix pull requests | Planned |
| Live deployment | Not started |

## Run the checks yourself

Requirements: Terraform, Docker.

    ./scripts/check.sh

It runs formatting, validation, the policy tests (the policy must pass the real code and must catch the bad examples in tests/fixtures), and Checkov.

## Design principles

- Default deny: network rules allow only what is explicitly needed.
- One rulebook, two enforcement points: see rulebook/rules.yaml.
- Honest limits: policies read code, where variables are unresolved. Runtime detection covers real deployed values.
- AI never applies changes: it only proposes, and a human merges.

## Repository layout

    modules/azure/network   Terraform module for the network
    envs/dev                Root configuration
    rulebook/               The shared rulebook
    policies/azure/         Custom Rego policies
    tests/fixtures/         Deliberately insecure examples used to test the policies
    scripts/check.sh        One command that runs every check
    .github/workflows/      CI pipeline

## Roadmap

1. AWS versions of the modules and policies, validated statically.
2. More rules (public storage, encryption, mandatory tags, secrets handling).
3. Connect the runtime scanner and the AI fix loop.
4. Live deployment on the first cloud account available, with OIDC (no stored credentials).
