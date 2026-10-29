SELECT COUNT(*) AS public_tables
FROM pg_tables
WHERE schemaname = 'public';