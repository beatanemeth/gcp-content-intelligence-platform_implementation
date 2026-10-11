"""Simulated view check: create the cleaned views in the BigQuery emulator.

Simulated, not real GCP: goccy/bigquery-emulator speaks the BigQuery API on the
laptop. The script creates the 3 cleaned views from the same SQL templates
Terraform uses, then checks their rows against the staging tables. Exits with 1
on any mismatch.

Run after check_staging.py, with the emulator still running: the emulator keeps
the loaded staging tables in memory only.

    python simulation/check_views.py

The expected values come from the staging tables, not fixed numbers, so the same
script works for the full dataset (step 8).
"""

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

# The same values as local.sql_placeholders in bigquery.tf.
PLACEHOLDERS = {
    "project": PROJECT,
    "staging_dataset": STAGING,
    "cleaned_dataset": CLEANED,
}

# Terraform's order: content reads the other 2 views.
VIEWS = ["blog_posts", "articles", "content"]


def ensure_dataset(client: bigquery.Client) -> None:
    """Create content_cleaned if it is missing.

    Get first, create only on NotFound: the emulator answers 500, not 409, to
    an existing dataset, and the client then retries for 10 minutes.
    """
    try:
        client.get_dataset(f"{PROJECT}.{CLEANED}")
    except NotFound:
        client.create_dataset(f"{PROJECT}.{CLEANED}")


def create_view(client: bigquery.Client, name: str) -> None:
    """Create one view from its template, replacing any older version."""
    template = (TEMPLATES / "cleaned" / f"{name}.sql.tftpl").read_text(encoding="utf-8")
    # substitute, not safe_substitute: a missing placeholder fails, as in
    # Terraform's templatefile().
    view = bigquery.Table(f"{PROJECT}.{CLEANED}.{name}")
    view.view_query = Template(template).substitute(PLACEHOLDERS)
    # Deleted and created again, so a changed SQL file takes effect.
    client.delete_table(view, not_found_ok=True)
    client.create_table(view)
    print(f"created {name}")


def count(client: bigquery.Client, sql: str) -> int:
    """Run a query that returns one number."""
    return next(iter(client.query(sql).result()))[0]


def main() -> int:
    client = bigquery.Client(
        project=PROJECT,
        credentials=AnonymousCredentials(),
        client_options=ClientOptions(api_endpoint=EMULATOR),
    )
    ensure_dataset(client)
    for name in VIEWS:
        create_view(client, name)

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
        status = "ok" if result == expected else "FAIL"
        failed = failed or status == "FAIL"
        print(f"{status:4}  {check:20}  {view:10}  {result:>4}  (expected {expected})")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
