---
name: commit
description: Stage and commit changes with a subject line that follows writer-commits.md. Commits only the files the maintainer names (or has already staged); everything else stays for a later commit.
argument-hint: '[what to include, e.g. "only the settings file"]'
disable-model-invocation: true
allowed-tools: Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git branch*), Bash(git add*), Bash(git restore --staged*), Bash(git commit*), Bash(git switch -c*)
---

# Commit

Maintainer's hint: $ARGUMENTS

## Steps

1. **Read the state:** `git status --short`, `git diff --staged`, `git diff`, and `git branch --show-current`.
2. **Branch check:** never commit on `main`. If the current branch is `main`, propose a name (`<type>/<short-topic>`, see `writer-commits.md`), wait for confirmation, then `git switch -c <name>`.
3. **Choose what to commit**, in this order:
   - **Hint given:** commit only the files the hint describes. If something is already staged that the hint does not cover, list it and ask before unstaging it.
   - **No hint, something staged:** commit exactly the staged files. Stage nothing more.
   - **No hint, nothing staged:** group the changed and untracked files into logical changes (one type and scope each). One group: commit it. Several groups: list them and ask which to commit now. The rest stays unstaged for later.
4. **Stage by path:** `git add <path> ...` for the chosen files only. Never `git add -A`, `git add .` or `git commit -a`.
5. **Part of a file:** if one file holds changes for two different commits, stop. Ask the maintainer to stage the wanted part with `git add -p <file>`, then run `/commit` again.
6. **Safety check:** never stage `terraform.tfvars`, `backend.hcl`, `*.tfstate*`, `.build/`, `.terraform/` or anything under `data/raw/`. If one is in the selection, stop and say so.
7. **Write the subject line** from the staged diff, following `writer-commits.md`: type, optional scope, description, spelling. Subject line only.
8. **Commit:** `git commit -m "<subject>"`, with a single `-m`, so there is no body or footer.
9. **Report:** the commit hash and subject, and the files still uncommitted (from `git status --short`). Do not push.
