import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from cloudevents.http import CloudEvent
from google.cloud import bigquery

import main
from main import GROUPS, handle_event, is_too_old, ready_group

DUMMY = Path(__file__).parents[2] / "data" / "dummy"
BUCKET = "content-demo-sim-content-data"
UTC = timezone.utc  # noqa: UP017 (the laptop runs Python 3.10)

# The record counts of the dummy data (step 1).
COUNTS = {
    "blog_posts": 75,
    "blog_categories": 6,
    "blog_tags": 11,
    "members": 5,
    "articles": 12,
    "article_categories": 5,
}


# Fake clients: they keep the files in a dict and record each load, so the tests
# need no GCP project and no credentials.


class FakeBlob:
    def __init__(self, bucket, name):
        self.bucket = bucket
        self.name = name

    def download_as_text(self):
        return self.bucket.files[self.name]

    def upload_from_string(self, data, content_type=None):
        self.bucket.files[self.name] = data


class FakeBucket:
    name = BUCKET

    def __init__(self, files):
        self.files = files

    def blob(self, name):
        return FakeBlob(self, name)


class FakeStorageClient:
    def __init__(self, bucket):
        self._bucket = bucket

    def bucket(self, name):
        assert name == BUCKET
        return self._bucket


class FakeLoadJob:
    def __init__(self, output_rows):
        self.output_rows = output_rows

    def result(self):
        return self


class FakeBigQueryClient:
    def __init__(self, bucket):
        self.bucket = bucket
        self.loads = []

    def load_table_from_uri(self, uri, destination, job_config):
        self.loads.append((uri, destination, job_config))
        # The rows a real load would add: one per line of the processed file.
        path = uri.removeprefix(f"gs://{BUCKET}/")
        return FakeLoadJob(len(self.bucket.files[path].splitlines()))


@pytest.fixture
def cloud(monkeypatch):
    """The data bucket with the dummy exports under raw/, and the fake clients."""
    files = {
        f"raw/{group}/{name}.json": (DUMMY / group / f"{name}.json").read_text(
            encoding="utf-8"
        )
        for group, names in GROUPS.items()
        for name in names
    }
    bucket = FakeBucket(files)
    bq = FakeBigQueryClient(bucket)
    monkeypatch.setattr(
        main.storage, "Client", lambda **kwargs: FakeStorageClient(bucket)
    )
    monkeypatch.setattr(main.bigquery, "Client", lambda **kwargs: bq)
    # The environment variables Terraform sets on the function.
    monkeypatch.setenv("PROJECT_ID", "content-demo-sim")
    monkeypatch.setenv("STAGING_DATASET", "content_staging")
    monkeypatch.setenv("BQ_LOCATION", "europe-west1")
    return bucket, bq


def event(name: str, age: timedelta = timedelta(0)) -> CloudEvent:
    """An upload event as Eventarc sends it, from a file finished age ago."""
    time = (datetime.now(UTC) - age).isoformat().replace("+00:00", "Z")
    attributes = {
        "type": "google.cloud.storage.object.v1.finalized",
        "source": f"//storage.googleapis.com/projects/_/buckets/{BUCKET}",
        "time": time,
    }
    return CloudEvent(attributes, {"bucket": BUCKET, "name": name})


def processed(bucket: FakeBucket) -> dict:
    return {
        path: text
        for path, text in bucket.files.items()
        if path.startswith("processed/")
    }


def logs(capsys) -> list[dict]:
    return [json.loads(line) for line in capsys.readouterr().out.splitlines()]


@pytest.mark.parametrize(
    ("name", "group"),
    [
        ("raw/blogs/_READY", "blogs"),
        ("raw/articles/_READY", "articles"),
        ("raw/blogs/blog_posts.json", None),
        ("processed/blogs/members.ndjson", None),
    ],
)
def test_ready_group(name, group, capsys):
    assert ready_group(name) == group
    assert capsys.readouterr().out == ""


@pytest.mark.parametrize("name", ["raw/videos/_READY", "blogs/_READY", "_READY"])
def test_ready_group_misplaced_marker_warns(name, capsys):
    assert ready_group(name) is None
    assert [line["severity"] for line in logs(capsys)] == ["WARNING"]


def test_is_too_old_at_the_limit():
    now = datetime(2026, 10, 11, 12, 0, tzinfo=UTC)

    assert not is_too_old("2026-10-11T11:45:00.000Z", now)
    assert is_too_old("2026-10-11T11:44:59.999Z", now)


def test_data_file_event_stops_at_once(cloud, capsys):
    bucket, bq = cloud

    handle_event(event("raw/blogs/blog_posts.json"))

    assert processed(bucket) == {}
    assert bq.loads == []
    assert capsys.readouterr().out == ""


def test_old_marker_event_stops_with_warning(cloud, capsys):
    bucket, bq = cloud

    handle_event(event("raw/blogs/_READY", age=timedelta(minutes=16)))

    assert processed(bucket) == {}
    assert bq.loads == []
    assert [line["severity"] for line in logs(capsys)] == ["WARNING"]


@pytest.mark.parametrize("group", GROUPS)
def test_fresh_marker_event_loads_group(group, cloud, capsys):
    bucket, bq = cloud

    handle_event(event(f"raw/{group}/_READY"))

    names = GROUPS[group]
    # Only this group's files, each with one line per record.
    assert sorted(processed(bucket)) == sorted(
        f"processed/{group}/{n}.ndjson" for n in names
    )
    for name in names:
        lines = bucket.files[f"processed/{group}/{name}.ndjson"].splitlines()
        assert len(lines) == COUNTS[name]

    assert [(uri, table) for uri, table, _ in bq.loads] == [
        (
            f"gs://{BUCKET}/processed/{group}/{n}.ndjson",
            f"content-demo-sim.content_staging.{n}",
        )
        for n in names
    ]
    for _, _, config in bq.loads:
        assert config.source_format == bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
        assert config.write_disposition == bigquery.WriteDisposition.WRITE_TRUNCATE
        assert config.schema is None  # the table's own schema applies

    assert [line["message"] for line in logs(capsys)] == [
        f"{group}/{n}: {COUNTS[n]} records written, {COUNTS[n]} rows loaded"
        for n in names
    ]


def test_same_event_twice_overwrites(cloud):
    bucket, _ = cloud
    marker = event("raw/blogs/_READY")

    handle_event(marker)
    first = processed(bucket)
    handle_event(marker)

    assert processed(bucket) == first
