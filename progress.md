# Progress

The build log. The [plan](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning/tree/main/rebuild_plan) says what should happen; this file says what did. Deviations from the plan are recorded here, not in the plan.

<br>

## Status

**2026-10-12:** the simulated build is complete (steps 1 to 8, step 9 part 1). Branch `refactor/docs-and-folders` cuts the docs and moves the folders. Next: step 9, part 2 (`docs/real-deployment`): the real run, once a real GCP project exists.

<br>

## Merged branches

| PR  | Branch                            | Step      |
| --- | --------------------------------- | --------- |
| #1  | `chore/repository-and-dummy-data` | 1         |
| #2  | `feature/terraform-skeleton`      | 2         |
| #3  | `feature/python-cleaning`         | 3         |
| #4  | `feature/bigquery-staging`        | 4         |
| #5  | `feature/service-accounts`        | 5a        |
| #6  | `feature/function-and-trigger`    | 5b        |
| #7  | `feature/cleaned-views`           | 6         |
| #8  | `feature/analysis-views`          | 7         |
| #9  | `docs/full-dataset-run`           | 8         |
| #10 | `docs/runbook`                    | 9, part 1 |

<br>

## Deviations by step

All checks are simulated; the numbers (tests, rows) are in `simulation/README.md`.

### Step 1: repository, dummy data, pre-commit

- **Python 3.10.12 venv, not 3.14:** 3.14 is not installed on the laptop. CI and the function stay on 3.14.
- **`CLAUDE.md` commands grow each step:** the plan adds them in step 8; the "Commands" section now starts in step 1.

### Step 2: Terraform skeleton and the 2 buckets

- **Lock file for `linux_amd64` only:** another platform needs `terraform providers lock -platform=<platform>`.

### Step 3: Python cleaning

- **Python 3.10.12 on the laptop (the maintainer's decision):** no 3.11+ syntax; CI checks 3.14. Ruff targets `py314`.
- **Function `requirements.txt` in commit 1:** `requirements-dev.txt` includes it with `-r`.
- **Ruff 0.16.10 kept:** 0.17.0 was out at build time. Ruff also formats Python code blocks in Markdown.

### Step 4: BigQuery datasets, staging tables, data checks

- **Dataset `description`:** each dataset gets the text from the `datasets` local.
- **`averageRating` as `FLOAT`:** a rating such as 4.5 would fail a load into `INTEGER`.
- **`missing_titles` also counts an empty title.**
- **`tomap()` in test assertions:** an object never equals a map.

### Step 5a: service accounts and grants

- **Names not in the plan:** the `project_roles` keys, the grant resources (`runtime_data`, `runtime_staging`, `build_code_reader`) and 2 display names.
- **Project-level grants tested as a set of `"<role> <member>"` pairs:** an extra, missing or swapped grant fails.
- **`override_resource` per instance** works, though the Terraform docs do not mention instance keys.

### Step 5b: function, trigger, upload script

- **`Z` replaced by `+00:00` before `fromisoformat` (needed):** Python 3.10 cannot read `Z`.
- **`timezone.utc` with `# noqa: UP017` (needed):** `datetime.UTC` needs 3.11.
- **`google-cloud-bigquery==3.46.1`, not 3.45.2:** step 4 already pinned it; the pin moved to the function's `requirements.txt`.
- **`depends_on` on whole resources:** the function waits for all project-level grants, including the runtime's `jobUser`.
- **One `override_resource` per account in `function.tftest.hcl`:** shared defaults would let a swapped account pass.
- **`upload_data.sh` changes to the repository root first:** it then works from any folder.

### Step 6: cleaned views

- **Whole table paths quoted in `check_views.py` (needed):** the emulator never returns on a path quoted in 2 parts.
- **No VS Code settings committed:** the editor tip stays a per-user setting.

### Step 7: analysis views

- **`top_posts_per_category` partitions by category ID, not label.**
- **`report()` in `check_views.py`:** one helper prints every check's line.
- **`--results` sorts by the first 2 columns:** the CSV files are the same on every run.
- **Open:** "proof that the check can fail" was never recorded for this step.

### Step 8: full dataset run

- **No `ERROR` for `members`:** this export states `_totalCount: 8`, so the totals match. The plan expected 9. `test_main.py` still covers the mismatch path.

### Step 9, part 1: Part A stand-in and runbook

- **Order: billing, APIs, then budget (needed):** the budget call needs its API enabled first.
- **`--billing-project` on the budget commands (needed):** the Billing Budget API is charged to a quota project.
- **Versioning with `buckets update`, on every run (needed):** `buckets create` has no versioning flag.
- **`--calendar-period=month` (explicit):** the reference states no default.
