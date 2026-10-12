"""Simulated staging check: load the NDJSON files into the BigQuery emulator.

Simulated, not real GCP: goccy/bigquery-emulator speaks the BigQuery API on the
laptop. The script loads the 6 NDJSON files from .build/ndjson/ as a real load
would, runs scripts/data_checks.sql and compares each result with its expected
value. Exits with 1 on any mismatch.

Start the emulator first (it creates content_staging; the script never does):

    docker run --rm -p 9050:9050 ghcr.io/goccy/bigquery-emulator:0.8.1 \\
        --project=content-demo-sim --dataset=content_staging

Then, in a second terminal:

    python tests/simulation/check_staging.py                 # dummy data
    python tests/simulation/check_staging.py --counts full   # full dataset (step 8)

A stopped emulator looks like a slow query, not an error: if the script hangs,
check `docker ps` first.

The emulator misses 2 rules real BigQuery enforces: it loads a record with an
unknown field (and drops the field), and one without the REQUIRED _id.
tests/function/test_schemas.py covers both.
"""

import argparse
import sys
from pathlib import Path

from google.api_core.client_options import ClientOptions
from google.auth.credentials import AnonymousCredentials
from google.cloud import bigquery

ROOT = Path(__file__).parents[2]
NDJSON = ROOT / ".build" / "ndjson"
SCHEMAS = ROOT / "terraform" / "modules" / "content_pipeline" / "schemas"
CHECKS = ROOT / "scripts" / "data_checks.sql"

EMULATOR = "http://localhost:9050"
PROJECT = "content-demo-sim"
DATASET = "content_staging"

# The expected record count per table; every other check expects 0.
COUNTS = {
    "dummy": {
        "blog_posts": 75,
        "blog_categories": 6,
        "blog_tags": 11,
        "members": 5,
        "articles": 12,
        "article_categories": 5,
    },
    "full": {
        "blog_posts": 113,
        "blog_categories": 9,
        "blog_tags": 17,
        "members": 8,
        "articles": 18,
        "article_categories": 8,
    },
}


def load(client: bigquery.Client, path: Path) -> None:
    """Load one NDJSON file into the staging table of the same name."""
    config = bigquery.LoadJobConfig(
        schema=client.schema_from_json(SCHEMAS / f"{path.stem}.json"),
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        # A second run replaces the rows instead of adding them again.
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        # Strict defaults, as in the real load: no bad record allowed
        # (max_bad_records 0), no unknown field (ignore_unknown_values False).
    )
    table = f"{PROJECT}.{DATASET}.{path.stem}"
    with path.open("rb") as file:
        client.load_table_from_file(file, table, job_config=config).result()
    print(f"loaded  {path.stem}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--counts", choices=COUNTS, default="dummy")
    counts = COUNTS[parser.parse_args().counts]

    files = sorted(NDJSON.glob("*/*.ndjson"))
    if {path.stem for path in files} != set(counts):
        print(f"Expected the 6 NDJSON files in {NDJSON}; run main.py first.")
        return 1

    client = bigquery.Client(
        project=PROJECT,
        credentials=AnonymousCredentials(),
        client_options=ClientOptions(api_endpoint=EMULATOR),
    )
    for path in files:
        load(client, path)

    failed = False
    for row in client.query(CHECKS.read_text(encoding="utf-8")).result():
        expected = counts[row.table_name] if row.check_name == "row_count" else 0
        status = "ok" if row.result == expected else "FAIL"
        failed = failed or status == "FAIL"
        print(
            f"{status:4}  {row.check_name:17}  {row.table_name:22}"
            f"  {row.result:>4}  (expected {expected})"
        )

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
