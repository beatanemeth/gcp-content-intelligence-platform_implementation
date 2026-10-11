# Simulation

No real GCP project is used. Every cloud check runs on the laptop, and every simulated result is labelled as simulated.

<br>

## Why simulate

- **No GCP project:** the pipeline is built and checked without credentials or cost.
- **Part B needs only Part A's values:** the module is built against the values the platform would hand over, not against the platform itself.
- **No code change later:** a real deployment (step 9) swaps the simulated values for real ones.

<br>

## Simulated Part A values

Made up; they point to nothing real.

| Value                 | Simulated value            | Enters Part B as                   |
| --------------------- | -------------------------- | ---------------------------------- |
| **Project ID**        | `content-demo-sim`         | `project_id` in `terraform.tfvars` |
| **Region**            | `europe-west1`             | `region` in `terraform.tfvars`     |
| **State bucket name** | `content-demo-sim-tfstate` | `bucket` in `backend.hcl`          |

### Derived names

| Resource          | Name                              |
| ----------------- | --------------------------------- |
| **Data bucket**   | `content-demo-sim-content-data`   |
| **Source bucket** | `content-demo-sim-content-source` |

<br>

## Labelling rule

Every simulated result, in this file, `progress.md` or `README.md`, is labelled as **simulated**. Later steps add their simulated checks below.
