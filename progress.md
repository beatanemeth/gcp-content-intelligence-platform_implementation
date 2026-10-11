# Progress

The build log. The [plan](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning/tree/main/rebuild_plan) says what should happen; this file says what did. Deviations from the plan are recorded here, not in the plan.

<br>

## Status

**2026-10-11:** step 2 (Terraform skeleton and the 2 buckets) is in review. Next: step 3 (Python cleaning).

<br>

## Merged branches

| PR      | Branch                            | Step |
| ------- | --------------------------------- | ---- |
| #1      | `chore/repository-and-dummy-data` | 1    |
| Pending | `feature/terraform-skeleton`      | 2    |

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

### Step 2: Terraform skeleton and the 2 buckets

- **Built:**
  - **Module** `terraform/modules/content_pipeline/`: 2 inputs, the `content` prefix and 2 labels, the data and source buckets, the `data_bucket_name` output, a README.
  - **Root module** `terraform/environments/dev/`: `~> 1.16` and `google ~> 8.6`, a partial `gcs` backend (`prefix = "content-pipeline"`), the 2 `*.example` files, the lock file (google `8.6.0`).
  - **Checks:** `tests/storage.tftest.hcl`; `.tflint.hcl` (plugins `terraform` 0.15.0, `google` 0.40.0); `pre-commit-terraform` `v1.109.2` with 3 hooks; the `Terraform checks` workflow.
- **Checked (simulated):**
  - **`terraform test`:** 1 run passed against the mocked provider.
  - **`fmt`, `validate`, TFLint:** pass; TFLint reports nothing.
  - **pre-commit:** all hooks pass, including the 3 Terraform hooks.
  - **Workflow:** not run yet; it must be green on the pull request.
- **Deviations:**
  - **Lock file for `linux_amd64` only:** `terraform init` records checksums for the laptop's platform. CI runs on the same platform. Another platform needs `terraform providers lock -platform=<platform>`.
  - **Plan clarified:** the 2 meanings of "raw" (the laptop's `data/raw/` and the bucket's `raw/`) are now in `step-0_overview.md` of the planning repository. No decision changed.

<br>

## Open points

- **Python 3.14:** install it on the laptop and rebuild `.venv` before step 3.
- **The 2 meanings of "raw" in `README.md` (step 5b):** with the upload script, add a short data note: `data/dummy/` and `data/raw/` on the laptop; `raw/` and `processed/` in the bucket.
