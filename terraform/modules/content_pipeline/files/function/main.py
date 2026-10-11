"""Clean the Wix exports: remove the wrapper and write NDJSON for BigQuery."""

import json

# The record key and its total key of each wrapped export.
ENVELOPES = [("_items", "_totalCount"), ("items", "totalCount")]


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
