locals {
  feature = "content"

  labels = {
    feature    = "content-pipeline"
    managed_by = "terraform"
  }

  datasets = {
    staging  = "The data as delivered: one table per NDJSON file, strict schemas."
    cleaned  = "Prepared data, as views on the staging tables."
    analysis = "Answers, as views on the cleaned layer."
  }

  staging_tables = toset([
    "blog_posts",
    "blog_categories",
    "blog_tags",
    "members",
    "articles",
    "article_categories",
  ])

  # content reads these two, so it has its own block in bigquery.tf.
  cleaned_views = toset([
    "blog_posts",
    "articles",
  ])

  analysis_views = toset([
    "content_per_month",
    "tag_frequency",
    "top_posts_per_category",
    "article_text_stats",
  ])

  service_accounts = {
    build   = "Content pipeline: function build"
    trigger = "Content pipeline: event trigger"
    runtime = "Content pipeline: function runtime"
  }

  # No bucket- or dataset-level equivalent.
  project_roles = {
    runtime_job_user = {
      account = "runtime"
      role    = "roles/bigquery.jobUser"
    }
    trigger_event_receiver = {
      account = "trigger"
      role    = "roles/eventarc.eventReceiver"
    }
    build_artifact_writer = {
      account = "build"
      # Project level: Google creates the repository on first deploy.
      role = "roles/artifactregistry.writer"
    }
    build_log_writer = {
      account = "build"
      role    = "roles/logging.logWriter"
    }
  }
}
