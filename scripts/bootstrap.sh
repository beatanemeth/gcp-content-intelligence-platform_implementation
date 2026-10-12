#!/usr/bin/env bash
# Part A stand-in: create the platform basics that Part B (the Terraform module)
# expects to exist. In the story, Team A built them; here this script does.
#
# When: once, by hand, before the first terraform init with the real backend.
# It changes the cloud, so it never runs in the simulation or in CI.
#
# Usage, from any folder:
#   PROJECT_ID=<project-id> BILLING_ACCOUNT=<billing-account-id> scripts/bootstrap.sh
#
# Safe to run again: each step checks whether its result exists, or is a no-op
# when it does (enabling an API, granting a role).
#
# Team B's Owner role comes with creating the project, so no grant is needed.

set -euo pipefail # stop at the first error, an unset variable or a failed pipe

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:?Set BILLING_ACCOUNT}"

# The same values as terraform.tfvars and backend.hcl.
REGION="europe-west1"
STATE_BUCKET="${PROJECT_ID}-tfstate"

# In the billing account's currency; the budget only alerts, it never stops spending.
BUDGET_NAME="${PROJECT_ID}-budget"
BUDGET_AMOUNT="10"

# The 10 APIs Part B needs, plus the Billing Budget API for the budget below.
APIS=(
    storage.googleapis.com
    cloudfunctions.googleapis.com
    run.googleapis.com
    cloudbuild.googleapis.com
    artifactregistry.googleapis.com
    eventarc.googleapis.com
    pubsub.googleapis.com
    bigquery.googleapis.com
    iam.googleapis.com
    cloudresourcemanager.googleapis.com
    billingbudgets.googleapis.com
)

echo "1. Project: $PROJECT_ID"
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    gcloud projects create "$PROJECT_ID"
fi

echo "2. Billing link"
if [[ "$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingEnabled)')" != "True" ]]; then
    gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
fi

# Before the budget: most APIs need billing, and the budget call needs its API.
echo "3. APIs"
gcloud services enable "${APIS[@]}" --project="$PROJECT_ID"

echo "4. Budget: $BUDGET_AMOUNT per month, alerts at 50, 90 and 100 %"
# Alert emails go to the billing account's administrators and users (the default).
# --billing-project: the budget API is charged to this project, where it is enabled.
if [[ -z "$(gcloud billing budgets list --billing-account="$BILLING_ACCOUNT" \
    --billing-project="$PROJECT_ID" \
    --filter="displayName=$BUDGET_NAME" --format='value(name)')" ]]; then
    gcloud billing budgets create \
        --billing-account="$BILLING_ACCOUNT" \
        --billing-project="$PROJECT_ID" \
        --display-name="$BUDGET_NAME" \
        --budget-amount="$BUDGET_AMOUNT" \
        --calendar-period=month \
        --filter-projects="projects/$PROJECT_ID" \
        --threshold-rule=percent=0.5 \
        --threshold-rule=percent=0.9 \
        --threshold-rule=percent=1.0
fi

echo "5. Terraform state bucket: gs://$STATE_BUCKET"
if ! gcloud storage buckets describe "gs://$STATE_BUCKET" >/dev/null 2>&1; then
    gcloud storage buckets create "gs://$STATE_BUCKET" \
        --project="$PROJECT_ID" \
        --location="$REGION" \
        --uniform-bucket-level-access \
        --public-access-prevention
fi
# Versioning: an older state can be restored if a run corrupts it.
# buckets create has no versioning flag, so it is set here, on every run.
gcloud storage buckets update "gs://$STATE_BUCKET" --versioning

echo "6. Cloud Storage service agent: roles/pubsub.publisher"
# The service agent publishes the bucket's events to Pub/Sub for Eventarc.
# The command prints the agent's email and creates the agent if it does not exist yet.
STORAGE_AGENT="$(gcloud storage service-agent --project="$PROJECT_ID")"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$STORAGE_AGENT" \
    --role="roles/pubsub.publisher" \
    --condition=None >/dev/null

echo "Done. Part A is ready for Part B: see docs/runbook.md, step 3."
