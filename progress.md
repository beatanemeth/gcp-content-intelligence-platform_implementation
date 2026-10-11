# Progress

The build log. The [plan](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning/tree/main/rebuild_plan) says what should happen; this file says what did. Deviations from the plan are recorded here, not in the plan.

<br>

## Status

**2026-10-11:** step 1 (repository, dummy data, pre-commit) is in review. Next: step 2 (Terraform skeleton and the 2 buckets).

<br>

## Merged branches

| PR      | Branch                            | Step |
| ------- | --------------------------------- | ---- |
| Pending | `chore/repository-and-dummy-data` | 1    |

<br>

## What each step changed

### Step 1: repository, dummy data, pre-commit

- **Built:** `.gitignore` with every entry for all steps; the 6 dummy files in `data/dummy/`; `requirements-dev.txt` (`pre-commit==4.6.2`); `.pre-commit-config.yaml` with `pre-commit/pre-commit-hooks` `v6.0.0`; `simulation/README.md`; `docs/decisions.md`; the `README.md` story; the Claude Code set-up.
- **Checked:**
  - **Record counts:** 75, 6, 11, 5, 12 and 5, as in the plan; every category, tag and member ID in the blog posts resolves.
  - **pre-commit:** all 7 hooks pass; the dummy data keeps the same SHA-256 checksums after the run.
  - **`.gitignore`:** `git check-ignore -v` names the matching line for `data/raw/test.json` and `terraform.tfvars`.
- **Deviations:**
  - **Python 3.10.12 venv, not 3.14:** Python 3.14 is not installed on the laptop yet. Step 1 needs only pre-commit, which runs on 3.10. Switch to 3.14 before step 3.
  - **`CLAUDE.md` commands grow each step:** the plan adds the check commands in step 8. A "Commands" section now starts in step 1 and each step adds its own, so the commands stay in one place during the build.

<br>

## Open points

- **Python 3.14:** install it on the laptop and rebuild `.venv` before step 3.
