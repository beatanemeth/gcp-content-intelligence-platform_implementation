# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. General working rules live in `.claude/rules/`.

<br>

## Project context

- **Purpose:** a portfolio project: a hands-on **Terraform** and **GCP** build. It rebuilds a local Docker and Jupyter project ([Wix Content Intelligence Pipeline](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline)) as a cloud data pipeline.
- **Implementation:** this repository holds the code: Terraform, Python, SQL, shell scripts and CI workflows.
- **Plan:** every design decision lives in the planning repository ([GitHub](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning); local clone at `../gcp-content-intelligence-platform_planning/`). This repository implements it; it does not re-decide it.
- **Progress:** `progress.md` records the merged branches, the steps done, the deviations from the plan and the next step. Read it at the start of a session.

<br>

## The story

Imagine a company that already runs a GCP platform. This project adds a **new feature** to it: the content pipeline, delivered as a **standalone Terraform module**.

- **Part A: the _platform_ (Team A).**
  - The shared foundation, applied once and kept. It holds everything that more than one feature uses.
  - Part A is **never built here**. Part B is built against the values Part A would hand over (`content-demo-sim`, `europe-west1`, `content-demo-sim-tfstate`).
  - Part B assumes Part A already did these: billing linked to the project, the 10 APIs enabled, the Cloud Storage service agent's `roles/pubsub.publisher`, `Owner` for Team B.
  - For the real deployment, a `gcloud` script (`helpers/bootstrap.sh`, step 9) stands in for Part A.
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

A real deployment comes later (step 9) and needs no code change.

<br>

## Where to find the plan

Paths are relative to the planning repository. `rebuild_plan/` holds the reviewed, final plan; `review_plan/` and `architecture/` are earlier drafts and do not decide anything.

| File                               | Holds                                                    |
| ---------------------------------- | -------------------------------------------------------- |
| `rebuild_plan/README.md`           | The project in short; the list of steps                  |
| `rebuild_plan/step-0_overview.md`  | The story, the repository layout, naming, tool versions  |
| `rebuild_plan/step-<n>_<topic>.md` | One step: in plain words, technical details, "Done when" |

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

| Command                                                   | Checks                                          | Step |
| --------------------------------------------------------- | ----------------------------------------------- | ---- |
| `pre-commit run --all-files`                              | File checks, Terraform and Ruff hooks; dummy data intact | 1, 2, 3 |
| `git check-ignore -v data/raw/test.json terraform.tfvars` | Private files match a `.gitignore` line         | 1    |

### Terraform checks (steps 2, 4)

```bash
tflint --init --config "$(pwd)/.tflint.hcl"        # once: installs the pinned plugins
terraform fmt -check -recursive terraform

cd terraform/environments/dev
terraform init -backend=false && terraform validate   # also validates the module

cd ../../modules/content_pipeline
terraform init -backend=false && terraform test       # simulated: mocked provider, 2 runs

cd ../../..
tflint --recursive --config "$(pwd)/.tflint.hcl"     # full path: one config for every folder
```

### Python checks (steps 3, 4)

```bash
pytest                                     # 26 tests on the dummy data
ruff check && ruff format --check
python terraform/modules/content_pipeline/files/function/main.py data/dummy .build/ndjson
wc -l .build/ndjson/*/*.ndjson             # 75, 6, 11, 5, 12 and 5 lines
```

### Staging checks (step 4)

Simulated with the BigQuery emulator; needs Docker and the NDJSON files from the Python checks.

```bash
# Terminal 1: creates content_staging at start; stop with Ctrl+C
docker run --rm -p 9050:9050 ghcr.io/goccy/bigquery-emulator:0.8.1 \
    --project=content-demo-sim --dataset=content_staging

# Terminal 2
python simulation/check_staging.py        # every check ok, exit code 0
```

<br>

## Project goals

- **Focus:** _Data Engineering_.
- **Practice:** puts Google Professional Data Engineer knowledge into practice with _Terraform_ on _GCP_.
- **SQL:** the transformations and data quality checks.
- **CI:** _GitHub Actions_ runs `terraform fmt`, `terraform validate`, `terraform test`, TFLint, pytest, Ruff and ShellCheck; no cloud access. Each step adds its own checks.
- **Scope:** simple but _production-minded_; the maintainer can explain every part.
- **Method:** built step by step; one step, one branch, one pull request. Each step ends with its "Done when" check.
