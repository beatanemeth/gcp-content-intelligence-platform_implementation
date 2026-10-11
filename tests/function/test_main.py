import json
from pathlib import Path

import pytest

from main import unwrap

DUMMY = Path(__file__).parents[2] / "data" / "dummy"

# The record counts of the dummy data (step 1).
DUMMY_COUNTS = [
    ("blogs", "blog_posts", 75),
    ("blogs", "blog_categories", 6),
    ("blogs", "blog_tags", 11),
    ("blogs", "members", 5),
    ("articles", "articles", 12),
    ("articles", "article_categories", 5),
]


def load(group: str, name: str) -> list | dict:
    return json.loads((DUMMY / group / f"{name}.json").read_text(encoding="utf-8"))


@pytest.mark.parametrize(("group", "name", "count"), DUMMY_COUNTS)
def test_unwrap_dummy_export(group, name, count, capsys):
    records = unwrap(name, load(group, name))

    assert len(records) == count
    assert "ERROR" not in capsys.readouterr().out


def test_unwrap_cut_off_export_logs_error(capsys):
    data = load("blogs", "members")
    data["_items"] = data["_items"][:2]

    records = unwrap("members", data)

    assert len(records) == 2
    line = json.loads(capsys.readouterr().out)
    assert line == {
        "severity": "ERROR",
        "message": "members: 2 records, the export says 5",
    }


def test_unwrap_unknown_shape_raises():
    with pytest.raises(ValueError, match="unknown export shape"):
        unwrap("other", {"rows": []})
