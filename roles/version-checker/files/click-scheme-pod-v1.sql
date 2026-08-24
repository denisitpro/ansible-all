-- example sceme version monitoring - pod version

CREATE DATABASE IF NOT EXISTS infra;

CREATE TABLE infra.k8s_versions
(    
  `timestamp` DateTime DEFAULT now(),
  `cluster` String,
  `namespace` String,
  `appname` String,
  `pod_name` String,
  `registry_path` String,
  `version` String
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (cluster, namespace, appname, pod_name, version )
TTL toStartOfDay(timestamp) + INTERVAL 3 DAY
SETTINGS index_granularity = 8192;
