"""Clean the Wix exports: remove the wrapper and write NDJSON for BigQuery."""

import json
import sys
from pathlib import Path

from bs4 import BeautifulSoup

# The 6 exports, by group. A missing file fails loudly instead of silently
# shrinking the group.
GROUPS = {
    "blogs": ["blog_posts", "blog_categories", "blog_tags", "members"],
    "articles": ["articles", "article_categories"],
}

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


if __name__ == "__main__":
    # python main.py <source folder> <target folder>
    process_folder(Path(sys.argv[1]), Path(sys.argv[2]))
