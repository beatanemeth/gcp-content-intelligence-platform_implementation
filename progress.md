# Progress

The build log. The [plan](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning/tree/main/rebuild_plan) says what should happen; this file says what did. Deviations from the plan are recorded here, not in the plan.

<br>

## Status

**2026-10-11:** step 6 (the cleaned views) is in review. Next: step 7 (the analysis views).

<br>

## Merged branches

| PR      | Branch                            | Step |
| ------- | --------------------------------- | ---- |
| #1      | `chore/repository-and-dummy-data` | 1    |
| #2      | `feature/terraform-skeleton`      | 2    |
| #3      | `feature/python-cleaning`         | 3    |
| #4      | `feature/bigquery-staging`        | 4    |
| #5      | `feature/service-accounts`        | 5a   |
| #6      | `feature/function-and-trigger`    | 5b   |
| Pending | `feature/cleaned-views`           | 6    |

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

### Step 3: Python cleaning, on the laptop

- **Built:**
  - **`main.py`** in `terraform/modules/content_pipeline/files/function/`: `log`, `unwrap`, `clean_html`, `transform`, `to_ndjson`, `process_folder` and a command-line entry. Based on the original project's [Jupyter ETL notebooks](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline/tree/main/ETL): their unwrap and HTML cleaning steps, simplified; their lookups and renames move to SQL (steps 6 and 7).
  - **Tests:** `tests/function/test_main.py`, the plan's 9 tests (19 runs with `parametrize`).
  - **Settings:** `pyproject.toml` (pytest, Ruff); `requirements-dev.txt` adds `pytest==9.1.1` and `ruff==0.16.10`; the function's `requirements.txt` (`beautifulsoup4==4.15.0`); `ruff-pre-commit` `v0.16.10` with `ruff-check` and `ruff-format`; the `Python tests` workflow (Python 3.14, `actions/setup-python@v7`).
- **Checked:**
  - **pytest:** 19 passed on Python 3.10.12.
  - **Ruff:** `ruff check` and `ruff format --check` pass.
  - **Command line:** 6 NDJSON files with 75, 6, 11, 5, 12 and 5 lines; a second run gives the same files.
  - **Leftovers:** no wrapper, HTML tag or HTML entity is left in any field of the transformed dummy data or the full dataset (field paths checked, no content copied).
  - **pre-commit:** all hooks pass, including the 2 Ruff hooks.
  - **Workflow:** not run yet; it must be green on the pull request (the first run on Python 3.14).
- **Deviations:**
  - **Python 3.10.12 on the laptop, not 3.14:** the maintainer's decision. CI and the function's runtime stay on 3.14, and Ruff targets `py314`. The code must also run on 3.10 (no 3.11+ syntax); the workflow checks it on 3.14.
  - **Function `requirements.txt` in commit 1:** `requirements-dev.txt` includes it with `-r`, so it must exist first. No decision changed.
  - **Ruff 0.16 also formats Python code blocks in Markdown files:** `ruff format` checks them too; they all pass. Ruff 0.17.0 was out at build time; the plan's 0.16.10 was kept.

### Step 4: BigQuery datasets, staging tables, data checks

- **Built:**
  - **Module:** the `datasets` and `staging_tables` locals; `bigquery.tf` with the 3 datasets (`content_staging`, `content_cleaned`, `content_analysis`) and the 6 staging tables; the `dataset_ids` output, passed on in `environments/dev/outputs.tf`.
  - **Schemas:** `files/schemas/<table>.json`, 6 files built from the dummy data, with the Wix field names.
  - **Checks:** `tests/bigquery.tftest.hcl`; `tests/function/test_schemas.py` (7 tests); `helpers/data_checks.sql` (18 rows: 4 checks); `simulation/check_staging.py`; `requirements-dev.txt` adds `google-cloud-bigquery==3.46.1`; the `Python tests` workflow also runs on schema and `simulation/` changes.
- **Checked (simulated):**
  - **`terraform test`:** 2 runs passed against the mocked provider.
  - **pytest:** 26 passed on Python 3.10.12, including `test_schemas.py`.
  - **Schemas against the full dataset:** every field path and type fits (field paths checked, no content copied). `tagIds` is sometimes empty and `manualSort` sometimes missing; `REPEATED` and `NULLABLE` accept both.
  - **`fmt`, `validate`, TFLint, Ruff:** pass.
  - **`check_staging.py` on the emulator:** the 6 files loaded; every check `ok`; exit code 0.
  - **Proof that the checks can fail:** one duplicate line in `members.ndjson` gives `row_count` 6 and `duplicate_keys` 1, both `FAIL`, exit code 1. Rebuilt with `main.py`: every check `ok` again.
  - **Workflows:** not run yet; both must be green on the pull request.
- **Deviations:**
  - **Dataset `description`:** not in the plan's argument table; each dataset gets the text from the `datasets` local, so its purpose shows in the console.
  - **`averageRating` as `FLOAT`:** the dummy and full data hold only the integer 0. A rating such as 4.5 would fail the whole load into an `INTEGER` column.
  - **`missing_titles` also counts an empty title:** `title IS NULL OR TRIM(title) = ''`.
  - **`tomap()` in the test assertions:** a `{ ... }` literal and a `{ for ... }` expression are objects; an object never equals a map, so the first `terraform test` failed on the `dataset_ids` output.
  - **Python 3.10 warning:** the Google libraries print a `FutureWarning` (Python 3.10 is past end of life). Harmless; it goes away with Python 3.11 or newer.

### Step 5a: service accounts and grants

- **Built:**
  - **Module:** the `service_accounts` and `project_roles` locals; `iam.tf` with the 3 accounts (`content-build`, `content-trigger`, `content-runtime`) and 7 grants, all `*_iam_member`: `objectUser` on the data bucket, `dataEditor` on `content_staging`, 4 project-level roles, and the build account's `objectViewer` with the `content-build-code-buckets-only` condition.
  - **Checks:** `tests/iam.tftest.hcl`; `storage.tftest.hcl` and `bigquery.tftest.hcl` give the mocked accounts a valid `member`.
- **Checked (simulated):**
  - **`terraform test`:** 3 runs passed against the mocked provider.
  - **Proof that the test can fail:** the runtime account's `dataEditor` on `content_cleaned` fails the IAM test ("The runtime account needs dataEditor on content_staging only."). Undone.
  - **`fmt`, `validate`, TFLint:** pass; TFLint reports nothing.
  - **Workflow:** not run yet; it must be green on the pull request.
- **Deviations:**
  - **Names not in the plan:** the `project_roles` keys (`runtime_job_user`, `trigger_event_receiver`, `build_artifact_writer`, `build_log_writer`), the grant resources (`runtime_data`, `runtime_staging`, `build_code_reader`) and 2 display names (`Content pipeline: event trigger`, `Content pipeline: function runtime`).
  - **The project-level grants in the IAM test:** checked as a set of `"<role> <member>"` pairs, so an extra, missing or swapped grant fails.
  - **`override_resource` per instance:** the plan's `google_service_account.pipeline["build"]` targets work; the Terraform docs do not mention instance keys, but the test proves each account gets its own `member`.

### Step 5b: function, trigger, upload script

- **Built:**
  - **Module:** the `archive` provider (`>= 2.0`; `~> 2.8` in the root module, lock file `2.8.1`); `function.tf` with the zip, its upload (`function-source-<md5>.zip`), the `content-transform` function and its trigger, and the 8th grant (`run.invoker` for the trigger account); the `function_name` output, passed on in `environments/dev/outputs.tf`.
  - **`main.py`:** `MARKER`, `MAX_EVENT_AGE`, `LOAD_CONFIG`; `ready_group`, `is_too_old`, `process_file` and `handle_event`. The function's `requirements.txt` adds `functions-framework==3.10.2`, `google-cloud-bigquery==3.46.1` and `google-cloud-storage==3.17.0`.
  - **Checks:** `tests/function/test_handle_event.py` (7 tests, 13 runs); `tests/function.tftest.hcl`; `helpers/upload_data.sh`; `shellcheck-py` `v0.11.0.1-1` in pre-commit; the `Shell checks` workflow.
- **Checked (simulated):**
  - **`terraform test`:** 4 runs passed against the mocked provider; the real `archive` provider zips only `main.py` and `requirements.txt` (no `__pycache__`).
  - **pytest:** 39 passed on Python 3.10.12, including `test_handle_event.py`.
  - **Upload order:** with fake `terraform` and `gcloud` first on `PATH`, each group's files come before its marker; a failing `gcloud` stops the script before the marker; a missing group folder stops it with exit code 1.
  - **`fmt`, `validate`, TFLint, Ruff, ShellCheck:** pass.
  - **Proof that the test can fail:** run by the maintainer: `RETRY_POLICY_DO_NOT_RETRY` fails the function test. Undone.
  - **Workflows:** not run yet; all 3 must be green on the pull request.
- **Deviations:**
  - **`Z` replaced by `+00:00` before `fromisoformat` (needed):** Cloud Storage writes the event time with a `Z`; Python 3.10 on the laptop cannot read it and raises `ValueError`, 3.11 and newer can. The plan assumed Python 3.14 everywhere.
  - **`timezone.utc` with `# noqa: UP017` (needed):** Ruff targets `py314` and asks for `datetime.UTC`, which Python 3.10 does not have (added in 3.11). `timezone.utc` works on both.
  - **`google-cloud-bigquery==3.46.1`, not 3.45.2 (kept):** step 4 already pinned 3.46.1; the plan's version was the newest when the plan was written. The pin moves from `requirements-dev.txt` to the function's `requirements.txt`.
  - **`depends_on` on whole resources (simplification):** Terraform tracks a dependency on the whole resource, even when one instance is named. The function waits for all of `google_project_iam_member.pipeline` and for `build_code_reader`: the plan's 4 grants plus the runtime's `jobUser`, which does no harm.
  - **One `override_resource` per account in `function.tftest.hcl` (needed):** the plan has `mock_resource` defaults plus an override for the trigger account only. With shared defaults, build and runtime get the same `id` and `email`, so a swapped account would still pass. Each account gets its own `id`, `email` and `member`, as in `iam.tftest.hcl`.
  - **`upload_data.sh` changes to the repository root first:** the `terraform -chdir=...` path and the default `data/dummy` then work from any folder.

### Step 6: cleaned views

- **Built:**
  - **SQL templates** in `terraform/modules/content_pipeline/templates/cleaned/`: `blog_posts.sql.tftpl` (author nickname; categories and tags as `ARRAY` of `STRUCT`, one subquery each), `articles.sql.tftpl` (category title), `content.sql.tftpl` (both, `UNION ALL`).
  - **Module:** the `cleaned_views` local in `main.tf`; in `bigquery.tf`, the `sql_placeholders` local, `google_bigquery_table.cleaned` (`blog_posts`, `articles`) and `google_bigquery_table.content`, with `depends_on` per layer.
  - **Checks:** `run "cleaned_views"` in `tests/bigquery.tftest.hcl`; `simulation/check_views.py`.
- **Checked (simulated):**
  - **`terraform test`:** `bigquery.tftest.hcl` passed both runs (`datasets_and_staging_tables`, `cleaned_views`) against the mocked provider.
  - **`check_staging.py`, then `check_views.py` on the emulator:** every check `ok`, exit code 0: 75 posts, 12 articles, 87 content rows, no duplicate ID, no empty name, no missing article text.
  - **Joins resolve on the dummy data:** every post has an author nickname and at least one category; the views hold all 315 tag links of the staging table; every article has a category title.
  - **`fmt`, `validate`, TFLint, Ruff:** pass; TFLint reports nothing.
  - **Workflows:** not run yet; both must be green on the pull request.
- **Deviations:**
  - **Whole table paths quoted in `check_views.py` (needed):** the emulator never returns on `` `project.dataset`.table `` (a path quoted in 2 parts), which real BigQuery accepts. The script writes `` `project.dataset.table` ``, as the templates do.
  - **No VS Code settings committed:** the plan's editor tip (`files.associations` for `*.sql.tftpl`) stays a per-user setting.

<br>

## Open points

- None.
