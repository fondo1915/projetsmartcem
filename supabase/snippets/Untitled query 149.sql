SELECT extname FROM pg_extension WHERE extname = 'vector';

SELECT unnest(enum_range(NULL::public.error_category)) AS error_category;