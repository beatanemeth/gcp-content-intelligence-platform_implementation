"""Simulated view check: create the cleaned and analysis views in the BigQuery
emulator.

Simulated, not real GCP: goccy/bigquery-emulator speaks the BigQuery API on the
laptop. The script creates the 3 cleaned views and the 4 analysis views from the
same SQL templates Terraform uses. It checks the cleaned views' rows against the
staging tables, and that every analysis view returns rows. Exits with 1 on any
failed check.

Run after check_staging.py, with the emulator still running: the emulator keeps
the loaded staging tables in memory only.

    python simulation/check_views.py
    python simulation/check_views.py --results .build/results-simulated

--results also writes each analysis view to <folder>/<view>.csv, after the
checks. The numbers come from the emulator: simulated results (step 8).

The expected values come from the staging tables, not fixed numbers, so the same
script works for the full dataset (step 8).
"""

import argparse
import csv
import sys
from pathlib import Path
from string import Template

from google.api_core.client_options import ClientOptions
from google.api_core.exceptions import NotFound
from google.auth.credentials import AnonymousCredentials
from google.cloud import bigquery

ROOT = Path(__file__).parents[1]
TEMPLATES = ROOT / "terraform" / "modules" / "content_pipeline" / "templates"

EMULATOR = "http://localhost:9050"
PROJECT = "content-demo-sim"
STAGING = "content_staging"
CLEANED = "content_cleaned"
ANALYSIS = "content_analysis"

# The same values as local.sql_placeholders in bigquery.tf.
PLACEHOLDERS = {
    "project": PROJECT,
    "staging_dataset": STAGING,
    "cleaned_dataset": CLEANED,
}

# Per layer: its dataset and its views, in Terraform's order. content reads the
# other 2 cleaned views; the analysis views read the cleaned views.
LAYERS = {
    "cleaned": (CLEANED, ["blog_posts", "articles", "content"]),
    "analysis": (
        ANALYSIS,
        [
            "content_per_month",
            "tag_frequency",
            "top_posts_per_category",
            "article_text_stats",
        ],
    ),
}


def ensure_dataset(client: bigquery.Client, dataset: str) -> None:
    """Create the dataset if it is missing.

    Get first, create only on NotFound: the emulator answers 500, not 409, to
    an existing dataset, and the client then retries for 10 minutes.
    """
    try:
        client.get_dataset(f"{PROJECT}.{dataset}")
    except NotFound:
        client.create_dataset(f"{PROJECT}.{dataset}")


def create_view(client: bigquery.Client, layer: str, name: str) -> None:
    """Create one view from its template, replacing any older version."""
    dataset = LAYERS[layer][0]
    template = (TEMPLATES / layer / f"{name}.sql.tftpl").read_text(encoding="utf-8")
    # substitute, not safe_substitute: a missing placeholder fails, as in
    # Terraform's templatefile().
    view = bigquery.Table(f"{PROJECT}.{dataset}.{name}")
    view.view_query = Template(template).substitute(PLACEHOLDERS)
    # Deleted and created again, so a changed SQL file takes effect.
    client.delete_table(view, not_found_ok=True)
    client.create_table(view)
    print(f"created {dataset}.{name}")


def count(client: bigquery.Client, sql: str) -> int:
    """Run a query that returns one number."""
    return next(iter(client.query(sql).result()))[0]


def report(check: str, view: str, result: int, passed: bool, expected: str) -> bool:
    """Print one check's line; return True if it failed."""
    status = "ok" if passed else "FAIL"
    print(f"{status:4}  {check:20}  {view:22}  {result:>4}  (expected {expected})")
    return not passed


def save_results(client: bigquery.Client, folder: Path) -> None:
    """Write each analysis view to <folder>/<view>.csv, with a header row."""
    folder.mkdir(parents=True, exist_ok=True)
    for view in LAYERS["analysis"][1]:
        # ORDER BY 1, 2: the first 2 columns are each view's key, so the file
        # is the same on every run. A view itself keeps no row order.
        result = client.query(
            f"SELECT * FROM `{PROJECT}.{ANALYSIS}.{view}` ORDER BY 1, 2"
        ).result()
        path = folder / f"{view}.csv"
        with path.open("w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            writer.writerow(field.name for field in result.schema)
            writer.writerows(row.values() for row in result)
        print(f"wrote {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--results", type=Path, metavar="FOLDER")
    results = parser.parse_args().results

    client = bigquery.Client(
        project=PROJECT,
        credentials=AnonymousCredentials(),
        client_options=ClientOptions(api_endpoint=EMULATOR),
    )
    for layer, (dataset, views) in LAYERS.items():
        ensure_dataset(client, dataset)
        for name in views:
            create_view(client, layer, name)

    staging = f"{PROJECT}.{STAGING}"
    cleaned = f"{PROJECT}.{CLEANED}"
    posts = count(client, f"SELECT COUNT(*) FROM `{staging}.blog_posts`")
    articles = count(client, f"SELECT COUNT(*) FROM `{staging}.articles`")

    # (check, view, query, expected)
    checks = [
        (
            "row_count",
            "blog_posts",
            f"SELECT COUNT(*) FROM `{cleaned}.blog_posts`",
            posts,
        ),
        (
            "distinct_ids",
            "blog_posts",
            f"SELECT COUNT(DISTINCT id) FROM `{cleaned}.blog_posts`",
            posts,
        ),
        (
            "row_count",
            "articles",
            f"SELECT COUNT(*) FROM `{cleaned}.articles`",
            articles,
        ),
        (
            "distinct_ids",
            "articles",
            f"SELECT COUNT(DISTINCT id) FROM `{cleaned}.articles`",
            articles,
        ),
        (
            "missing_article_text",
            "articles",
            f"SELECT COUNT(*) FROM `{cleaned}.articles`"
            " WHERE article_text IS NULL OR TRIM(article_text) = ''",
            0,
        ),
        (
            "row_count",
            "content",
            f"SELECT COUNT(*) FROM `{cleaned}.content`",
            posts + articles,
        ),
        (
            "empty_names",
            "content",
            f"SELECT COUNT(*) FROM `{cleaned}.content`,"
            " UNNEST(ARRAY_CONCAT(categories, tags)) AS name"
            " WHERE name IS NULL OR TRIM(name) = ''",
            0,
        ),
    ]

    failed = False
    for check, view, sql, expected in checks:
        result = count(client, sql)
        failed |= report(check, view, result, result == expected, f"{expected}")

    # has_rows: the analysis views have no staging number to match. An empty
    # answer means a broken join or filter. Runs even after a failed cleaned
    # check, so one report shows every failure.
    for view in LAYERS["analysis"][1]:
        rows = count(client, f"SELECT COUNT(*) FROM `{PROJECT}.{ANALYSIS}.{view}`")
        failed |= report("has_rows", view, rows, rows >= 1, ">= 1")

    if results:
        save_results(client, results)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
