locals {
  # Every GCP name starts with this prefix, so the feature's resources are easy
  # to spot in a project that other features share.
  feature = "content"

  # Goes on every resource that supports labels.
  labels = {
    feature    = "content-pipeline" # filter this feature's resources and costs
    managed_by = "terraform"        # tells others not to change it by hand
  }

  # One dataset per layer (medallion pattern). The key becomes the dataset's name
  # (content_<key>) and its layer label.
  datasets = {
    staging  = "The data as delivered: one table per NDJSON file, strict schemas."
    cleaned  = "Prepared data, as views on the staging tables."
    analysis = "Answers, as views on the cleaned layer."
  }

  # One staging table per NDJSON file, with the same name; each has its schema
  # in files/schemas/<name>.json.
  staging_tables = toset([
    "blog_posts",
    "blog_categories",
    "blog_tags",
    "members",
    "articles",
    "article_categories",
  ])
}
