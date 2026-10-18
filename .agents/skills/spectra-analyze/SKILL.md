---
name: spectra-analyze
description: "Analyze artifact consistency for an identified Spectra change — contradictions between proposal, design, specs, and tasks, plus gaps and ambiguity. Use when an identified Spectra change's artifacts may conflict before implementation"
argument-hint: "[change-name]"
license: MIT
compatibility: Requires spectra CLI.
metadata:
  author: spectra
  version: "1.0"
  generatedBy: "Spectra"
---

Load the complete `analyze` workflow for this tool at runtime.

1. Run `spectra instructions --skill analyze --agent codex`.
2. If the command fails, report the error and STOP.
3. Follow the returned workflow in the current session. Treat any argument supplied with this skill invocation as the workflow input.

Do not run this loader again from the returned workflow.
