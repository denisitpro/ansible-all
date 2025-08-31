-- Monitor query limits and performance
-- Run this periodically to check if settings are appropriate

-- Check current concurrent queries
SELECT 
    'Current concurrent queries' as metric,
    count() as value
FROM system.processes
WHERE query NOT LIKE '%system.processes%';

-- Check thread pool usage
SELECT 
    'Thread pool size' as metric,
    value as value
FROM system.settings 
WHERE name = 'max_thread_pool_size'
UNION ALL
SELECT 
    'Current threads' as metric,
    count() as value
FROM system.threads;

-- Check memory usage
SELECT 
    'Memory usage' as metric,
    formatReadableSize(value) as value
FROM system.metrics 
WHERE metric = 'MemoryTracking'
UNION ALL
SELECT 
    'Max memory usage' as metric,
    formatReadableSize(value) as value
FROM system.settings 
WHERE name = 'max_memory_usage';

-- Check recent errors
SELECT 
    'Recent errors' as metric,
    count() as value
FROM system.text_log 
WHERE level >= 3 
    AND event_time >= now() - INTERVAL 1 HOUR;
