-- Optimized schema for version monitoring - pod version
-- Optimized for: 8GB RAM, 4 cores, version monitoring every 5 minutes

CREATE DATABASE IF NOT EXISTS infra;

CREATE TABLE infra.k8s_versions
(    
  `timestamp` DateTime DEFAULT now(),
  `cluster` LowCardinality(String),
  `namespace` LowCardinality(String),
  `appname` LowCardinality(String),
  `pod_name` String,
  `registry_path` LowCardinality(String),
  `version` LowCardinality(String)
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (cluster, namespace, appname, pod_name)
TTL toStartOfDay(timestamp) + INTERVAL 7 DAY
SETTINGS 
  index_granularity = 8192,
  min_rows_for_wide_part = 1000000,
  min_bytes_for_wide_part = 100000000;
