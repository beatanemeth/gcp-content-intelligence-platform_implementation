"""Check the cleaned records against the staging schemas.

The BigQuery emulator loads a record with an unknown field (and drops the field)
or without a REQUIRED field; real BigQuery fails the load. This test covers both
rules offline, so CI also catches a change to the function or the schemas.
"""

import json
from pathlib import Path

import pytest

from main import GROUPS, transform

ROOT = Path(__file__).parents[2]
DUMMY = ROOT / "data" / "dummy"
SCHEMAS = ROOT / "terraform" / "modules" / "content_pipeline" / "files" / "schemas"

TABLES = [(group, name) for group, names in GROUPS.items() for name in names]


def schema_problems(record: dict, columns: list[dict], prefix: str = "") -> list[str]:
    """List the unknown fields and the missing REQUIRED fields of one record."""
    known = {column["name"] for column in columns}
    problems = [f"unknown field {prefix}{key}" for key in record if key not in known]

    for column in columns:
        name = column["name"]
        value = record.get(name)
        if value is None:
            if column["mode"] == "REQUIRED":
                problems.append(f"missing REQUIRED field {prefix}{name}")
        elif column["type"] == "RECORD":
            problems += schema_problems(value, column["fields"], f"{prefix}{name}.")

    return problems


@pytest.mark.parametrize(("group", "name"), TABLES)
def test_dummy_records_fit_their_schema(group, name):
    data = json.loads((DUMMY / group / f"{name}.json").read_text(encoding="utf-8"))
    schema = json.loads((SCHEMAS / f"{name}.json").read_text(encoding="utf-8"))

    problems = {
        problem
        for record in transform(name, data)
        for problem in schema_problems(record, schema)
    }

    assert problems == set()


def test_schema_problems_finds_a_bad_record():
    schema = json.loads((SCHEMAS / "members.json").read_text(encoding="utf-8"))
    record = {"status": "APPROVED", "profile": {"nickname": "Author 1", "age": 30}}

    assert schema_problems(record, schema) == [
        "missing REQUIRED field _id",
        "unknown field profile.age",
    ]
