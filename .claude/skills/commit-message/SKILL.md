---
name: commit-message
description: Draft a commit subject line that follows writer-commits.md, for the maintainer to commit. Changes nothing in git.
argument-hint: '[what the commit should cover, e.g. "the rules files"]'
disable-model-invocation: true
allowed-tools: Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git branch*)
---

# Commit message

Maintainer's hint: $ARGUMENTS

## Steps

1. **Read the state:** `git status --short`, `git diff --staged`, `git diff`, and `git branch --show-current`.
2. **Choose what the message covers**, in this order:
   - **Hint given:** the files the hint describes.
   - **No hint, something staged:** the staged files.
   - **No hint, nothing staged:** all changed and untracked files.
3. **Mixed changes:** if the chosen files hold more than one logical change (different types or scopes), propose one subject line per group, each with the `git add <path> ...` command that stages it.
4. **Write the subject line** following `writer-commits.md`: type, optional scope, description, spelling. Subject line only.
5. **Output:**
   - The subject line in a code block, ready to copy.
   - If the files are not staged yet: the `git add <path> ...` command for them.
   - A warning if the branch is `main`.
6. **Never run** `git add`, `git commit` or any other command that changes the repository.
