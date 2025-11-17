# MissingInProject fixtures

This directory mirrors the folder layout that the real icon-editor repository exposes under `.github/actions/missing-in-project`. The agent validation plan and VI Analyzer samples target this path via `src/configs/vi-analyzer/missing-in-project.viancfg` and `scenarios/*/vi-diff-requests.json`.

In environments that do not have the icon-editor artifacts, the folder merely acts as a placeholder so the JSON configs resolve cleanly. If you intend to run the analyzer or compare workflows against real VIs, clone or sync the icon-editor assets into this directory (preserving the same relative structure) before invoking x-cli.
