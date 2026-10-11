# GCP content intelligence platform: implementation

This repository rebuilds a local Docker and Jupyter project, the [Wix Content Intelligence Pipeline](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline), as a **cloud data pipeline on GCP**. The pipeline is a **standalone Terraform module** that a company's existing GCP platform can add without changes. The focus is **Data Engineering**.

Every design decision lives in the [planning repository](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning); this repository implements it.

> **Simulation only:** no real GCP is used. Every check runs on the laptop, and every simulated result is labelled as simulated. See [simulation/README.md](simulation/README.md).

### The story

- **Part A (the platform):** a company already runs a shared GCP platform with the project, billing, the enabled APIs and the Terraform state bucket.
- **Part B (the feature):** the content pipeline is a new feature on that platform, delivered as a standalone Terraform module.
- **Ownership rule:** a resource that a second feature would need belongs to Part A; everything else belongs to Part B, which changes nothing in Part A.

The main decisions, with their reasons and costs, are in [docs/decisions.md](docs/decisions.md).

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

- **`terraform test`:** creates the 2 buckets against a mocked provider, checks their names and settings, then destroys them. Expected: `1 passed, 0 failed`.
- **`pre-commit run --all-files`:** runs the general file checks, the Terraform hooks (`fmt`, `validate`, TFLint) and the Ruff hooks in one go.

### Python checks

```bash
pytest                # the cleaning functions on the dummy data
ruff check            # lint
ruff format --check   # format

# The cleaning on the laptop: writes 6 NDJSON files to the git-ignored .build/
python terraform/modules/content_pipeline/files/function/main.py data/dummy .build/ndjson
wc -l .build/ndjson/*/*.ndjson
```

- **`pytest`:** unwraps and cleans the 6 dummy exports. Expected: `19 passed`.
- **The command line:** expected line counts 75, 6, 11, 5, 12 and 5. A second run gives the same files.
