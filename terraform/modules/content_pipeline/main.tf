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

  # The cleaned views that read only staging tables, created together; each has
  # its SQL in templates/cleaned/<name>.sql.tftpl. content reads these two, so it
  # has its own block (bigquery.tf).
  cleaned_views = toset([
    "blog_posts",
    "articles",
  ])

  # The analysis views, one question each; each has its SQL in
  # templates/analysis/<name>.sql.tftpl.
  analysis_views = toset([
    "content_per_month",
    "tag_frequency",
    "top_posts_per_category",
    "article_text_stats",
  ])

  # One service account per job, so each gets only its own roles. The key becomes
  # the account's ID (content-<key>); the value is its display name.
  service_accounts = {
    build   = "Content pipeline: function build"
    trigger = "Content pipeline: event trigger"
    runtime = "Content pipeline: function runtime"
  }

  # Roles that exist only at project level: no bucket or dataset can hold them.
  # The key names the grant in the resource address.
  project_roles = {
    runtime_job_user = {
      account = "runtime"
      role    = "roles/bigquery.jobUser" # a job belongs to a project
    }
    trigger_event_receiver = {
      account = "trigger"
      role    = "roles/eventarc.eventReceiver"
    }
    build_artifact_writer = {
      account = "build"
      role    = "roles/artifactregistry.writer" # Google creates the repository at the first deploy
    }
    build_log_writer = {
      account = "build"
      role    = "roles/logging.logWriter" # logs are written per project
    }
  }
}
