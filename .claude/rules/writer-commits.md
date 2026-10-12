# Rules: commit messages

Commit messages follow [Conventional Commits](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13). The same format applies to pull request titles.

**Skills:** `/commit` stages and commits; `/commit-message` only drafts the subject line. Both apply this file.

## Format

```text
<type>(<optional scope>): <description>
```

- **Subject line only:** no body, no footer, no trailers (including `Co-Authored-By`).
- **Description:** mandatory; imperative, present tense ("add", not "added"); lowercase first letter; no full stop at the end.
- **Breaking change:** add `!` before the colon (for example, `feat(terraform)!: rename module output`). Explain it in the pull request description.
- **Motivation and plan reference:** go in the pull request description (for example, `Implements step 2 (rebuild_plan/step-2_terraform-skeleton.md).`), not in the commit.
- **Merge and revert commits:** keep git's default subject (`Merge branch '<branch name>'`, `Revert "<reverted commit subject line>"`).

## Spelling

Only the first letter of the description is lowercase. Every other word keeps its normal case.

| Word kind         | Rule                                | Example                                        |
| ----------------- | ----------------------------------- | ---------------------------------------------- |
| **File names**    | Exactly as on disk (case-sensitive) | `docs: add README.md for the module`           |
| **Proper nouns**  | Official spelling                   | `feat(terraform): add BigQuery staging tables` |
| **Abbreviations** | Uppercase                           | `ops(ci): add TFLint step`                     |
| **Identifiers**   | Exactly as in the code              | `feat(sql): add content_per_month view`        |
| **Disciplines**   | Capitalised, as in `writer-docs.md` | `docs: describe the Data Engineering focus`    |
| **Other words**   | Lowercase                           | `fix(function): skip events without marker`    |

- **Start with a verb:** an imperative verb (`add`, `fix`, `rename`) as the first word avoids any clash with a proper noun or file name.
- **Name the file:** write `README.md` (or its path), not "readme".
- **No backticks:** plain text with the exact case is enough.
- **British English:** as in `writer-british-english.md` (e.g., _optimise_, _behaviour_).

## Types

| Type       | Use for                                                                       |
| ---------- | ----------------------------------------------------------------------------- |
| `feat`     | A new pipeline capability: resources, function logic, views, upload behaviour |
| `fix`      | A bug fix in a previously added feature                                       |
| `refactor` | Restructuring without a behaviour change                                      |
| `perf`     | A refactor that improves performance                                          |
| `style`    | Formatting only (for example, `terraform fmt`)                                |
| `test`     | Adding or correcting tests                                                    |
| `docs`     | Documentation only                                                            |
| `build`    | Provider, tool or dependency versions; lock file; `requirements.txt`          |
| `ops`      | CI workflows, pre-commit and TFLint settings, the Part A stand-in script      |
| `chore`    | Maintenance: `.gitignore`, Claude settings, repository housekeeping           |

## Scopes

Optional. Use one of these, matching the top-level concern of the change:

| Scope       | Covers                                                         |
| ----------- | -------------------------------------------------------------- |
| `terraform` | `terraform/` (module and deployment)                           |
| `function`  | `function/`                                                    |
| `sql`       | View SQL templates and `scripts/data_checks.sql`               |
| `ci`        | `.github/workflows/`, `.pre-commit-config.yaml`, `.tflint.hcl` |
| `scripts`   | `scripts/upload_data.sh`, `scripts/bootstrap.sh`               |
| `data`      | `data/dummy/`                                                  |
| `claude`    | `CLAUDE.md`, `.claude/`                                        |

Never use an issue number as a scope.

## Examples

- `feat(terraform): add data and source buckets`
- `feat(function): unwrap envelopes and write NDJSON`
- `ops(ci): add Terraform checks workflow`
- `build(terraform): pin Google provider to 8.x`
- `chore(claude): add project settings and commit convention`

## Branches

One branch and one pull request per step. Use the branch name from the step table in `rebuild_plan/step-0_overview.md` (for example, `chore/repository-and-dummy-data`, `feature/terraform-skeleton`). The pattern is `<type>/<short-topic>`, with `feature/` for `feat` work.
