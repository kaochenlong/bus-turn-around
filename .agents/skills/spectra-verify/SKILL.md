---
name: spectra-verify
description: "Verify an identified Spectra change against its artifacts (specs, tasks, design). Use when an identified Spectra change needs task, requirement, and design conformance checked before archiving"
argument-hint: "[change-name]"
license: MIT
compatibility: Requires spectra CLI.
metadata:
  author: spectra
  version: "1.0"
  generatedBy: "Spectra"
---

Load the complete `verify` workflow for this tool at runtime.

1. Run `spectra instructions --skill verify --agent codex`.
2. If the command fails, report the error and STOP.
3. Follow the returned workflow in the current session. Treat any argument supplied with this skill invocation as the workflow input.

Do not run this loader again from the returned workflow.
