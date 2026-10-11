"""Clean the Wix exports: remove the wrapper and write NDJSON for BigQuery.

As a Cloud Run function, handle_event also loads the NDJSON files into the
staging tables."""

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import functions_framework
from bs4 import BeautifulSoup
from google.cloud import bigquery, storage

# The 6 exports, by group. A missing file fails loudly instead of silently
# shrinking the group.
GROUPS = {
    "blogs": ["blog_posts", "blog_categories", "blog_tags", "members"],
    "articles": ["articles", "article_categories"],
}

# The record key and its total key of each wrapped export.
ENVELOPES = [("_items", "_totalCount"), ("items", "totalCount")]

# The upload script sends raw/<group>/_READY after the group's files. Only the
# marker means "the group is complete": every other upload event is ignored.
MARKER = "_READY"

# A retry keeps the event's original time, so its age grows. A temporary problem
# recovers within minutes; an older event is a permanent failure.
MAX_EVENT_AGE = timedelta(minutes=15)

# No schema: BigQuery uses the staging table's own strict schema, so a field
# that does not fit fails the load. WRITE_TRUNCATE replaces the rows, so a
# repeated event gives the same table.
LOAD_CONFIG = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
)


def log(severity: str, message: str) -> None:
    """Print one JSON line; Cloud Logging reads severity as the log level."""
    print(json.dumps({"severity": severity, "message": message}))


def unwrap(name: str, data: list | dict) -> list[dict]:
    """Return the records of one export, without the Wix wrapper."""
    if isinstance(data, list):  # blog_posts, blog_categories, blog_tags
        return data
    for records_key, total_key in ENVELOPES:
        if records_key in data:
            records = data[records_key]
            total = data[total_key]
            # Log and go on: a retry cannot fix the source file.
            if len(records) != total:
                log("ERROR", f"{name}: {len(records)} records, the export says {total}")
            return records
    raise ValueError(f"{name}: unknown export shape")


def clean_html(html: str) -> str:
    """Turn an article's HTML body into one line of plain text."""
    # The space separator: without it, <strong>Lorem</strong>Ipsum becomes LoremIpsum.
    text = BeautifulSoup(html, "html.parser").get_text(" ")
    # split() with no argument splits on any whitespace: spaces, line breaks and \xa0.
    return " ".join(text.split())


def transform(name: str, data: list | dict) -> list[dict]:
    """Turn one Wix export into clean records: unwrap every file; for the
    articles, also turn the HTML body into text."""
    records = unwrap(name, data)
    if name == "articles":
        # A copy of each record with only articleText replaced.
        records = [
            {**record, "articleText": clean_html(record["articleText"])}
            for record in records
        ]
    return records


def to_ndjson(records: list[dict]) -> str:
    """Write one JSON record per line: the format BigQuery loads."""
    # ensure_ascii=False keeps accented letters as they are, not as \u00e9.
    return "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records)


def process_folder(source: Path, target: Path) -> None:
    """Write <target>/<group>/<name>.ndjson for each export in GROUPS."""
    for group, names in GROUPS.items():
        (target / group).mkdir(parents=True, exist_ok=True)
        for name in names:
            raw = (source / group / f"{name}.json").read_text(encoding="utf-8")
            records = transform(name, json.loads(raw))
            # Overwrite, never append: a second run gives the same files.
            output = target / group / f"{name}.ndjson"
            output.write_text(to_ndjson(records), encoding="utf-8")
            log("INFO", f"{group}/{name}: {len(records)} records written")


def ready_group(name: str) -> str | None:
    """Return the group of a raw/<group>/_READY marker; None for any other file."""
    parts = name.split("/")
    if parts[-1] != MARKER:
        return None
    if len(parts) == 3 and parts[0] == "raw" and parts[1] in GROUPS:
        return parts[1]
    # Warn, not raise: an error would make Eventarc retry an event that can
    # never succeed.
    log("WARNING", f"{name}: marker outside raw/<group>/, ignored")
    return None


def is_too_old(event_time: str, now: datetime) -> bool:
    """True when the event happened more than MAX_EVENT_AGE before now."""
    # Cloud Storage writes the time with a Z; Python 3.10 (the laptop) cannot
    # read the Z, 3.11 and newer can.
    happened = datetime.fromisoformat(event_time.replace("Z", "+00:00"))
    return now - happened > MAX_EVENT_AGE


def process_file(
    bucket: storage.Bucket, bq: bigquery.Client, dataset: str, group: str, name: str
) -> None:
    """Clean raw/<group>/<name>.json, write processed/, load it into staging."""
    raw = bucket.blob(f"raw/{group}/{name}.json").download_as_text()
    records = transform(name, json.loads(raw))
    # Overwrite, never append: a repeated event writes the same file.
    path = f"processed/{group}/{name}.ndjson"
    bucket.blob(path).upload_from_string(
        to_ndjson(records), content_type="application/x-ndjson"
    )
    # BigQuery reads the file from Cloud Storage itself; load jobs are free.
    job = bq.load_table_from_uri(
        f"gs://{bucket.name}/{path}", f"{dataset}.{name}", job_config=LOAD_CONFIG
    )
    job.result()  # waits; a failed load raises, so Eventarc retries the event
    rows = job.output_rows
    log("INFO", f"{group}/{name}: {len(records)} records written, {rows} rows loaded")


@functions_framework.cloud_event
def handle_event(cloud_event) -> None:
    """Process one group when its marker arrives; ignore every other upload."""
    # Returning without an error tells Eventarc the event is done: no retries.
    marker = cloud_event.data["name"]
    group = ready_group(marker)
    if group is None:
        return
    if is_too_old(cloud_event["time"], datetime.now(timezone.utc)):  # noqa: UP017 (runs on 3.10)
        log("WARNING", f"{marker}: older than {MAX_EVENT_AGE}, dropped")
        return

    # Settings come from Terraform as environment variables.
    project = os.environ["PROJECT_ID"]
    bucket = storage.Client(project=project).bucket(cloud_event.data["bucket"])
    bq = bigquery.Client(project=project, location=os.environ["BQ_LOCATION"])
    dataset = f"{project}.{os.environ['STAGING_DATASET']}"
    for name in GROUPS[group]:
        process_file(bucket, bq, dataset, group, name)


if __name__ == "__main__":
    # python main.py <source folder> <target folder>
    process_folder(Path(sys.argv[1]), Path(sys.argv[2]))
