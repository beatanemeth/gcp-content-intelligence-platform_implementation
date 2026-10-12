#!/usr/bin/env bash
# Upload the Wix exports to the data bucket: each group's files to raw/<group>/,
# then its empty _READY marker. The marker starts the function, which loads the
# group into the staging tables.
#
# When: after terraform apply. It changes the cloud, so it never runs
# in the simulation.
#
# Usage, from any folder (the data folder is relative to the repository root):
#   scripts/upload_data.sh [data folder]    # default: data/dummy
#
# Safe to run again: files and markers are overwritten; the loads replace the rows.

set -euo pipefail # stop at the first error, an unset variable or a failed pipe

cd "$(dirname "$0")/.."

DATA_DIR="${1:-data/dummy}"
# Not GROUPS: bash keeps the user's group IDs in GROUPS and ignores assignments to it.
DATA_GROUPS=(blogs articles)

for group in "${DATA_GROUPS[@]}"; do
    if [[ ! -d "$DATA_DIR/$group" ]]; then
        echo "Missing folder: $DATA_DIR/$group" >&2
        exit 1
    fi
done

# The bucket name comes from Terraform, so no name is typed twice.
BUCKET="$(terraform -chdir=terraform/environments/dev output -raw data_bucket_name)"

for group in "${DATA_GROUPS[@]}"; do
    gcloud storage cp "$DATA_DIR/$group"/*.json "gs://$BUCKET/raw/$group/"
    # A separate command: gcloud storage cp uploads several files in parallel, in
    # no fixed order, so a marker in the same command could land before a data file.
    gcloud storage cp - "gs://$BUCKET/raw/$group/_READY" </dev/null
done

echo "Uploaded. The function's name, to filter its logs:"
echo "  terraform -chdir=terraform/environments/dev output -raw function_name"
