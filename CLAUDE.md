# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. General working rules live in `.claude/rules/`.

<br>

## Project context

- **Purpose:** a portfolio project: a hands-on **Terraform** and **GCP** build. It rebuilds a local Docker and Jupyter project ([Wix Content Intelligence Pipeline](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline)) as a cloud data pipeline.
- **Implementation:** this repository holds the code: Terraform, Python, SQL, shell scripts and CI workflows.
- **Plan:** every design decision lives in the planning repository ([GitHub](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning); local clone at `../gcp-content-intelligence-platform_planning/`). This repository implements it; it does not re-decide it.
- **Progress:** `docs/for_AI/progress.md` records the merged branches, the steps done, the deviations from the plan and the next step. Read it at the start of a session.

<br>

## The story

Imagine a company that already runs a GCP platform. This project adds a **new feature** to it: the content pipeline, delivered as a **standalone Terraform module**.

- **Part A: the _platform_ (Team A).**
  - The shared foundation, applied once and kept. It holds everything that more than one feature uses.
  - Part A is **never built here**. Part B is built against the values Part A would hand over (`content-demo-sim`, `europe-west1`, `content-demo-sim-tfstate`).
  - Part B assumes Part A already did these: billing linked to the project, the 10 APIs enabled, the Cloud Storage service agent's `roles/pubsub.publisher`, `Owner` for Team B.
  - For the real deployment, a `gcloud` script (`scripts/bootstrap.sh`) stands in for Part A.
- **Part B: the _feature_ (Team B, the maintainer).**
  - The content **pipeline** as a standalone module, added to Part A without changing it.
  - It creates everything only the pipeline uses: buckets, the function and its trigger, BigQuery datasets, tables and views, and its own service accounts with their roles.
  - Both the module (`terraform/modules/content_pipeline/`) and the root module that calls it (`terraform/environments/dev/`) belong to Part B.
- **Ownership rule:** "Would a second feature need it?" Yes: Part A. No: Part B.

<br>

## Simulation only

No real GCP is used. Every cloud check runs on the laptop, and every simulated result is labelled as simulated.

| Layer     | Simulated with                                 |
| --------- | ---------------------------------------------- |
| Terraform | `terraform test` with a mocked Google provider |
| BigQuery  | `goccy/bigquery-emulator` in Docker            |
| Python    | pytest with fake cloud clients                 |

One real deployment ran on 2026-10-20 (step 9, part 2) with no change to the module; the results and findings are in `docs/for_AI/progress.md`.

<br>

## Where to find the plan

Paths are relative to the planning repository. `rebuild_plan/` holds the reviewed, final plan; `history/` (`v1_brainstorming/`, `v2_architecture/`, `v3_review_plan/`) holds earlier drafts and does not decide anything.

| File                               | Holds                                                    |
| ---------------------------------- | -------------------------------------------------------- |
| `rebuild_plan/README.md`           | The project in short; the list of steps                  |
| `rebuild_plan/step-0_overview.md`  | The story, the repository layout, naming, tool versions  |
| `rebuild_plan/step-<n>_<topic>.md` | One step: in plain words, technical details, "Done when" |

<br>

## Repository layout

As built; the planned layout is in `rebuild_plan/step-0_overview.md`.

```text
.
├── terraform/
│   ├── modules/content_pipeline/   # Part B: the module
│   │   ├── main.tf                 # shared names, labels, view lists (locals)
│   │   ├── storage.tf              # data and source buckets
│   │   ├── bigquery.tf             # 3 datasets, 6 staging tables, 3 cleaned and 4 analysis views
│   │   ├── iam.tf                  # 3 service accounts, 8 grants
│   │   ├── function.tf             # zip, content-transform function, trigger
│   │   ├── variables.tf, outputs.tf, versions.tf, README.md
│   │   ├── schemas/                # one JSON schema per staging table
│   │   ├── templates/cleaned/      # *.sql.tftpl
│   │   ├── templates/analysis/     # *.sql.tftpl
│   │   └── tests/                  # *.tftest.hcl, mocked Google provider
│   └── environments/dev/           # the root module: provider, backend, module call
├── function/                       # main.py, requirements.txt: the function code
├── scripts/                        # upload_data.sh, data_checks.sql, bootstrap.sh (Part A stand-in)
├── tests/
│   ├── README.md                   # what the simulation proves and where it stops
│   ├── function/                   # pytest for the function code
│   └── simulation/                 # check_staging.py, check_views.py (BigQuery emulator)
├── data/                           # dummy/ committed; raw/ git-ignored
├── docs/                           # decisions.md; runbook.md (real GCP, run on 2026-10-20); real-run/ (its terminal output)
│   └── for_AI/progress.md          # build log and deviations
├── assets/                         # the pipeline and deployment diagrams; real-run/ (Console screenshots)
└── .github/workflows/              # 3 offline CI workflows
```

<br>

## Commands

Run from the repository root unless noted. Each step adds its own commands. Cloud-changing commands are never listed here; see "Cloud safety" in `.claude/rules/engineer.md`.

### Set-up (step 1)

```bash
python3 -m venv .venv              # 3.10 on the laptop; CI and the function use 3.14
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
pre-commit install                 # runs the hooks at every git commit
```

### Checks

| Command                                                   | Checks                                                               | Step        |
| --------------------------------------------------------- | -------------------------------------------------------------------- | ----------- |
| `pre-commit run --all-files`                              | File checks, Terraform, Ruff and ShellCheck hooks; dummy data intact | 1, 2, 3, 5b |
| `pre-commit run shellcheck --all-files`                   | ShellCheck on `scripts/*.sh` (installed through pip)                 | 5b          |
| `git check-ignore -v data/raw/test.json terraform.tfvars` | Private files match a `.gitignore` line                              | 1           |

### Terraform checks (steps 2, 4, 5a, 5b, 6, 7)

```bash
tflint --init --config "$(pwd)/.tflint.hcl"        # once: installs the pinned plugins
terraform fmt -check -recursive terraform

cd terraform/environments/dev
terraform init -backend=false && terraform validate   # also validates the module

cd ../../modules/content_pipeline
terraform init -backend=false && terraform test       # simulated: mocked provider, 6 runs

cd ../../..
tflint --recursive --config "$(pwd)/.tflint.hcl"     # full path: one config for every folder
```

### Python checks (steps 3, 4, 5b)

```bash
pytest                                     # 39 tests; fake clients, no GCP
ruff check && ruff format --check
python function/main.py data/dummy .build/ndjson
wc -l .build/ndjson/*/*.ndjson             # 75, 6, 11, 5, 12 and 5 lines
```

### Staging and view checks (steps 4, 6, 7)

Simulated with the BigQuery emulator; needs Docker and the NDJSON files from the Python checks.

```bash
# Terminal 1: creates content_staging at start; stop with Ctrl+C
docker run --rm -p 9050:9050 ghcr.io/goccy/bigquery-emulator:0.8.1 \
    --project=content-demo-sim --dataset=content_staging

# Terminal 2
python tests/simulation/check_staging.py        # every check ok, exit code 0
python tests/simulation/check_views.py          # after check_staging.py; every check ok, exit code 0
python tests/simulation/check_views.py --results .build/results-simulated   # also writes 4 CSV files
```

### Full dataset run (step 8)

The real exports in the git-ignored `data/raw/`; a fresh emulator, so no dummy rows remain.

```bash
git status --short data/raw                # nothing
python function/main.py data/raw .build/ndjson   # 6 INFO lines
wc -l .build/ndjson/*/*.ndjson             # 113, 9, 17, 8, 18 and 8 lines
python tests/simulation/check_staging.py --counts full
python tests/simulation/check_views.py --results .build/results-simulated
```

- **Publishing rule:** only the analysis views' results leave the laptop, labelled as simulated, with author names replaced ("Author 1"). Never the records.

<br>

## Project goals

- **Focus:** _Data Engineering_.
- **Practice:** puts Google Professional Data Engineer knowledge into practice with _Terraform_ on _GCP_.
- **SQL:** the transformations and data quality checks.
- **CI:** _GitHub Actions_ runs `terraform fmt`, `terraform validate`, `terraform test`, TFLint, pytest, Ruff and ShellCheck; no cloud access. Each step adds its own checks.
- **Scope:** simple but _production-minded_; the maintainer can explain every part.
- **Method:** built step by step; one step, one branch, one pull request. Each step ends with its "Done when" check.
