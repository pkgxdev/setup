# AGENTS: setup

Public repository for installer scripts and GitHub Action setup.

## Core Commands

- `npm install`
- `npm run dist`
- `sh ./installer.sh --help`

## Always Do

- Keep installer behavior explicit across macOS, Linux, and Windows.
- Preserve action input/output contract stability.

## Ask First

- Any change to default install paths or update behavior.
- Any action permission or deployment behavior change.

## Never Do

- Never remove installer safety checks.
- Never introduce hidden network side effects without documentation.
