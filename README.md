# GCP content intelligence platform: implementation

This repository rebuilds a local Docker and Jupyter project, the [Wix Content Intelligence Pipeline](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline), as a **cloud data pipeline on GCP**. The pipeline is a **standalone Terraform module** that a company's existing GCP platform can add without changes. The focus is **Data Engineering**.

Every design decision lives in the [planning repository](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning); this repository implements it.

> **Simulation only:** no real GCP is used. Every check runs on the laptop, and every simulated result is labelled as simulated. See [simulation/README.md](simulation/README.md).

### The story

- **Part A (the platform):** a company already runs a shared GCP platform with the project, billing, the enabled APIs and the Terraform state bucket.
- **Part B (the feature):** the content pipeline is a new feature on that platform, delivered as a standalone Terraform module.
- **Ownership rule:** a resource that a second feature would need belongs to Part A; everything else belongs to Part B, which changes nothing in Part A.

The main decisions, with their reasons and costs, are in [docs/decisions.md](docs/decisions.md).

### How it works

![Content pipeline overview](assets/content_pipeline_overview.png)

| Stage          | Service                     | What happens                                                                               |
| -------------- | --------------------------- | ------------------------------------------------------------------------------------------ |
| **Upload**     | Upload script (laptop)      | The export files go to the data bucket, `raw/<group>/`; a `_READY` marker last             |
| **Processing** | Cloud Run function          | Started by the marker; removes the Wix wrapper, cleans HTML, writes NDJSON to `processed/` |
| **Staging**    | BigQuery `content_staging`  | 6 tables, loaded 1:1 from `processed/` with strict schemas                                 |
| **Cleaning**   | BigQuery `content_cleaned`  | 3 views: names joined in, one row per post or article                                      |
| **Analysis**   | BigQuery `content_analysis` | 4 views: one answer per content question                                                   |

- **The upload script:** `helpers/upload_data.sh` uploads each group's files, then its marker. It changes the cloud, so it never runs here.
- **2 meanings of "raw":** on the laptop, `data/dummy/` (made-up, committed) and `data/raw/` (the real exports, git-ignored); in the data bucket, `raw/` (the uploads) and `processed/` (the function's NDJSON).

### The 4 questions

One view in `content_analysis` per question. Each SQL file opens with its question and the exact definition of its metric.

| View                     | Question                                                                                                | SQL technique       |
| ------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------- |
| `content_per_month`      | How much content was published in each calendar month, per content type, and what is the running total? | Running total       |
| `tag_frequency`          | Which tags and keywords are used most, per content type?                                                | `CROSS JOIN UNNEST` |
| `top_posts_per_category` | Which 3 posts have the most views in each category, and who wrote them?                                 | Ranking             |
| `article_text_stats`     | How long are the articles on average, per category?                                                     | Text measure        |

### Results (simulated)

The full dataset (113 blog posts, 18 articles) on the local BigQuery emulator, 2026-10-11. Author names replaced.

| View                     | Main answer                                                                            |
| ------------------------ | -------------------------------------------------------------------------------------- |
| `content_per_month`      | Posts from 2019 to 2026, most in 2020 (33); articles since 2021                        |
| `tag_frequency`          | Top blog tag: "Inspiring" (83 of 113 posts); top article keyword: "community" (5 of 18) |
| `top_posts_per_category` | Most viewed: "The 8 Secrets of the 8-Step Espresso Routine" (4193 views); every top post by Author 1 |
| `article_text_stats`     | 434 to 521 words on average per category: about 3 minutes' reading                     |

### Main technologies used

- **Infrastructure as code:** Terraform with the Google provider
- **Cloud services (simulated):** Cloud Storage, Cloud Run functions, BigQuery, IAM
- **Processing:** Python 3.14, Beautiful Soup, Functions Framework
- **Quality:** pytest, Ruff, TFLint, ShellCheck, pre-commit
- **Simulation:** a mocked Google provider for `terraform test`; a local BigQuery emulator in Docker
- **CI:** GitHub Actions, offline checks only

<br>

## Technical details

### Prerequisites

- **Terraform** 1.16.5
- **TFLint** 0.64.0
- **Docker:** runs the BigQuery emulator for the simulated staging and view checks
- **Python** 3.10 or newer (CI and the function use 3.14)
- **No GCP account:** nothing in this repository needs credentials

### Operating system used

- Linux Mint 21.2

<br>

## Run it yourself

All commands run on the laptop and need no GCP credentials. Run them from the repository root unless noted.

### Set-up

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
pre-commit install                            # runs the checks at every git commit
tflint --init --config "$(pwd)/.tflint.hcl"   # installs the pinned TFLint plugins
```

### Terraform checks

```bash
terraform fmt -check -recursive terraform

cd terraform/environments/dev
terraform init -backend=false   # no state bucket, no login
terraform validate              # also validates the module it calls

cd ../../modules/content_pipeline
terraform init -backend=false
terraform test                  # simulated: mocked Google provider

cd ../../..
tflint --recursive --config "$(pwd)/.tflint.hcl"
```

- **`terraform test`:** creates the 2 buckets, the 3 BigQuery datasets, the 6 staging tables, the 3 cleaned views, the 4 analysis views, the 3 service accounts and their 8 grants, and the function with its trigger against a mocked provider, checks their names, settings and scopes, then destroys them. Expected: `6 passed, 0 failed`.
- **`pre-commit run --all-files`:** runs the general file checks, the Terraform hooks (`fmt`, `validate`, TFLint), the Ruff hooks and ShellCheck in one go.

### Python checks

```bash
pytest                # the cleaning and the entry point on the dummy data
ruff check            # lint
ruff format --check   # format

# The cleaning on the laptop: writes 6 NDJSON files to the git-ignored .build/
python terraform/modules/content_pipeline/files/function/main.py data/dummy .build/ndjson
wc -l .build/ndjson/*/*.ndjson
```

- **`pytest`:** unwraps and cleans the 6 dummy exports, then checks every cleaned record against its staging schema. Runs `handle_event` on fake upload events with fake Storage and BigQuery clients (simulated). Expected: `39 passed`.
- **The command line:** expected line counts 75, 6, 11, 5, 12 and 5. A second run gives the same files.

### Staging checks (simulated)

Loads the 6 NDJSON files into a local BigQuery emulator, then runs the data checks. Needs Docker and the NDJSON files from the Python checks.

```bash
# Terminal 1: the emulator, with the content_staging dataset; stop it with Ctrl+C
docker run --rm -p 9050:9050 ghcr.io/goccy/bigquery-emulator:0.8.1 \
    --project=content-demo-sim --dataset=content_staging

# Terminal 2
python simulation/check_staging.py
```

- **The load:** each file goes into its staging table with the table's strict schema, as a real load would.
- **The checks:** [helpers/data_checks.sql](helpers/data_checks.sql), one row per check and table. Expected: every row `ok`, exit code 0.
- **A hanging script:** a stopped emulator looks like a slow query. Check `docker ps` first.
- **`--counts full`:** expects the full dataset's counts (113, 9, 17, 8, 18 and 8). The real exports sit in the git-ignored `data/raw/` and are not in this repository; run `main.py data/raw .build/ndjson` first, on a fresh emulator.

| Check               | Question                                                                            | Expected                                  |
| ------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------- |
| `row_count`         | Did every record arrive?                                                            | The record counts: 75, 6, 11, 5, 12 and 5 |
| `duplicate_keys`    | Does any `_id` appear twice?                                                        | 0                                         |
| `orphan_references` | Does every category, tag, author and article category ID exist in its lookup table? | 0                                         |
| `missing_titles`    | Does every post and article have a title? An empty title counts as missing          | 0                                         |

### View checks (simulated)

Creates the 3 cleaned views and the 4 analysis views in the same emulator. Checks the cleaned views' rows against the staging tables, and that every analysis view returns rows. Run it after `check_staging.py`, with the emulator still running: it keeps the loaded tables in memory only.

```bash
# Terminal 2, after check_staging.py
python simulation/check_views.py
python simulation/check_views.py --results .build/results-simulated   # also writes each analysis view as CSV
```

- **The same SQL as Terraform:** the script fills in the templates in `terraform/modules/content_pipeline/templates/` with the same values as `bigquery.tf`. It creates `blog_posts`, `articles` and `content`, then the 4 analysis views: Terraform's order.
- **`--results <folder>`:** after the checks, writes `<folder>/<view>.csv` for each analysis view, with a header row. Simulated results; `.build/` is git-ignored.
- **Expected values from staging,** not fixed numbers. Expected: every row `ok`, exit code 0.

| Check                  | View                     | Expected                                   |
| ---------------------- | ------------------------ | ------------------------------------------ |
| `row_count`            | `blog_posts`, `articles` | The staging table's row count (75, 12)     |
| `distinct_ids`         | `blog_posts`, `articles` | The staging table's row count: no ID twice |
| `missing_article_text` | `articles`               | 0                                          |
| `row_count`            | `content`                | Posts + articles (87)                      |
| `empty_names`          | `content`                | 0 empty category or tag names              |
| `has_rows`             | Each analysis view       | At least 1 row                             |
