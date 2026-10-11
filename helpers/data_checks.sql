-- Data checks on the staging tables: one row per check and table.
--
-- BigQuery checks each row's shape (the schemas); these checks cover the
-- relations between rows. Every result is a count; the expected values:
--   row_count          the record counts (dummy: 75, 6, 11, 5, 12, 5)
--   duplicate_keys     0
--   orphan_references  0
--   missing_titles     0
--
-- Real GCP (step 9): bq query --use_legacy_sql=false < helpers/data_checks.sql
-- Simulated: simulation/check_staging.py runs it on the BigQuery emulator.
--
-- Orphans use LEFT JOIN ... WHERE <lookup>._id IS NULL, not NOT IN: the intent
-- stays clear, and NOT IN returns no row at all once the list holds a NULL, so a
-- NULL would hide every miss.

-- Did every record arrive?
SELECT 'row_count' AS check_name, 'blog_posts' AS table_name, COUNT(*) AS result
FROM content_staging.blog_posts
UNION ALL
SELECT 'row_count', 'blog_categories', COUNT(*) FROM content_staging.blog_categories
UNION ALL
SELECT 'row_count', 'blog_tags', COUNT(*) FROM content_staging.blog_tags
UNION ALL
SELECT 'row_count', 'members', COUNT(*) FROM content_staging.members
UNION ALL
SELECT 'row_count', 'articles', COUNT(*) FROM content_staging.articles
UNION ALL
SELECT 'row_count', 'article_categories', COUNT(*) FROM content_staging.article_categories

-- Does any _id appear twice?
UNION ALL
SELECT 'duplicate_keys', 'blog_posts', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.blog_posts
UNION ALL
SELECT 'duplicate_keys', 'blog_categories', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.blog_categories
UNION ALL
SELECT 'duplicate_keys', 'blog_tags', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.blog_tags
UNION ALL
SELECT 'duplicate_keys', 'members', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.members
UNION ALL
SELECT 'duplicate_keys', 'articles', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.articles
UNION ALL
SELECT 'duplicate_keys', 'article_categories', COUNT(*) - COUNT(DISTINCT _id)
FROM content_staging.article_categories

-- Does every reference exist in its lookup table? CROSS JOIN UNNEST checks each
-- ID of an array on its own.
UNION ALL
SELECT 'orphan_references', 'blog_posts.categoryIds', COUNT(*)
FROM content_staging.blog_posts AS post
CROSS JOIN UNNEST(post.categoryIds) AS category_id
LEFT JOIN content_staging.blog_categories AS category ON category._id = category_id
WHERE category._id IS NULL
UNION ALL
SELECT 'orphan_references', 'blog_posts.tagIds', COUNT(*)
FROM content_staging.blog_posts AS post
CROSS JOIN UNNEST(post.tagIds) AS tag_id
LEFT JOIN content_staging.blog_tags AS tag ON tag._id = tag_id
WHERE tag._id IS NULL
UNION ALL
SELECT 'orphan_references', 'blog_posts.memberId', COUNT(*)
FROM content_staging.blog_posts AS post
LEFT JOIN content_staging.members AS member ON member._id = post.memberId
WHERE member._id IS NULL
UNION ALL
SELECT 'orphan_references', 'articles.category', COUNT(*)
FROM content_staging.articles AS article
LEFT JOIN content_staging.article_categories AS category ON category._id = article.category
WHERE category._id IS NULL

-- Does every post and article have a title? An empty title counts as missing.
UNION ALL
SELECT 'missing_titles', 'blog_posts', COUNTIF(title IS NULL OR TRIM(title) = '')
FROM content_staging.blog_posts
UNION ALL
SELECT 'missing_titles', 'articles', COUNTIF(title IS NULL OR TRIM(title) = '')
FROM content_staging.articles
