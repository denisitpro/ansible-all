-- Cleanup script for ClickHouse logs optimization
-- Run this after applying new TTL settings

-- Force cleanup of old log data
-- This will trigger TTL cleanup and partition optimization
OPTIMIZE TABLE system.trace_log FINAL;
OPTIMIZE TABLE system.query_log FINAL;
OPTIMIZE TABLE system.metric_log FINAL;
OPTIMIZE TABLE system.asynchronous_metric_log FINAL;
OPTIMIZE TABLE system.part_log FINAL;
OPTIMIZE TABLE system.query_views_log FINAL;

-- Force TTL cleanup for all log tables
SYSTEM FLUSH LOGS;

-- Check current log sizes after cleanup
SELECT 
    database,
    table,
    formatReadableSize(sum(bytes)) as size
FROM system.parts 
WHERE database = 'system' 
    AND table IN ('trace_log', 'query_log', 'metric_log', 'asynchronous_metric_log', 'part_log', 'query_views_log')
GROUP BY database, table
ORDER BY sum(bytes) DESC;
