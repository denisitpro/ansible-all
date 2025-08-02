-- example sceme version monitoring - compose version

CREATE DATABASE IF NOT EXISTS infra;

CREATE TABLE infra.compose_versions
(    
  `timestamp` DateTime DEFAULT now(),
  `registry_path` String,
  `appname` String,
  `stand` String,
  `servername` String,
  `version` String
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (appname, stand, servername, version)
TTL toStartOfDay(timestamp) + toIntervalDay(3)
SETTINGS index_granularity = 8192;
