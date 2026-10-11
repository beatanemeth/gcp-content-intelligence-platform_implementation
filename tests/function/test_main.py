import json
from pathlib import Path

import pytest

from main import clean_html, process_folder, to_ndjson, transform, unwrap

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


def test_clean_html_gives_one_line_of_words():
    html = "<p>Lorem <strong>ipsum</strong>Dolor</p>\n<ul><li>sit</li></ul>"

    assert clean_html(html) == "Lorem ipsum Dolor sit"


def test_clean_html_decodes_entities():
    assert clean_html("<p>Salt&amp;pepper&nbsp;mix</p>") == "Salt&pepper mix"


def test_clean_html_on_dummy_articles():
    for record in transform("articles", load("articles", "articles")):
        text = record["articleText"]
        assert text
        for unwanted in ("<", ">", "\n", "  "):
            assert unwanted not in text


def test_transform_cleans_only_article_text():
    original = unwrap("articles", load("articles", "articles"))
    cleaned = transform("articles", load("articles", "articles"))

    for before, after in zip(original, cleaned, strict=True):
        assert after["articleText"] != before["articleText"]
        assert {**after, "articleText": None} == {**before, "articleText": None}


@pytest.mark.parametrize(
    ("group", "name", "count"),
    [row for row in DUMMY_COUNTS if row[1] != "articles"],
)
def test_transform_leaves_other_files_unchanged(group, name, count):
    data = load(group, name)

    assert transform(name, data) == unwrap(name, data)


def test_to_ndjson_writes_one_object_per_line():
    records = [{"title": "Első bejegyzés"}, {"tags": ["a", "b"], "count": 2}]

    ndjson = to_ndjson(records)

    assert ndjson.endswith("\n")
    lines = ndjson.splitlines()
    assert [json.loads(line) for line in lines] == records
    assert "Első" in lines[0]


def test_process_folder_writes_the_6_files_and_overwrites(tmp_path):
    process_folder(DUMMY, tmp_path)
    first_run = {p: p.read_bytes() for p in tmp_path.rglob("*.ndjson")}
    process_folder(DUMMY, tmp_path)
    second_run = {p: p.read_bytes() for p in tmp_path.rglob("*.ndjson")}

    for group, name, count in DUMMY_COUNTS:
        output = tmp_path / group / f"{name}.ndjson"
        assert len(output.read_text(encoding="utf-8").splitlines()) == count
    assert len(first_run) == 6
    assert second_run == first_run
