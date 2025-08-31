-- Optimized schema for version monitoring - compose version
-- Optimized for: 8GB RAM, 4 cores, version monitoring every 5 minutes

CREATE DATABASE IF NOT EXISTS infra;

CREATE TABLE infra.compose_versions
(    
  `timestamp` DateTime DEFAULT now(),
  `registry_path` LowCardinality(String),
  `appname` LowCardinality(String),
  `stand` LowCardinality(String),
  `servername` LowCardinality(String),
  `version` LowCardinality(String)
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (appname, stand, servername)
TTL toStartOfDay(timestamp) + INTERVAL 7 DAY
SETTINGS 
  index_granularity = 8192,
  min_rows_for_wide_part = 1000000,
  min_bytes_for_wide_part = 100000000;
