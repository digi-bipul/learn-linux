.. _sec-12-4:

============================================================
12.4 Modern Log Management
============================================================

12.4.1 The 2026 Logging Landscape
=====================================

By 2026, the industry has moved away from the JVM-heavy ELK stack (Elasticsearch,
Logstash, Kibana) due to cost and complexity. The modern stack is:

+---------------------+---------------------------------------------+
| Component           | Role                                        |
+=====================+=============================================+
| **Vector**          | Log collection, transformation, routing     |
|                     | (replaces Logstash, Filebeat, Fluentd)      |
+---------------------+---------------------------------------------+
| **Grafana Loki**    | Horizontally scalable log aggregation       |
|                     | (replaces Elasticsearch for logs)           |
+---------------------+---------------------------------------------+
| **OpenTelemetry**   | Unified telemetry: logs, metrics, traces    |
+---------------------+---------------------------------------------+

12.4.2 Local Logging: rsyslog and logrotate
=============================================

rsyslog
--------

.. code-block:: bash

    # /etc/rsyslog.conf
    module(load="imudp")
    input(type="imudp" port="514")
    module(load="imtcp")
    input(type="imtcp" port="514")

    template(name="json-template" type="list") {
        constant(value="{")
        constant(value="\"timestamp\":\"") property(name="timereported" dateformat="rfc3339")
        constant(value="\",\"host\":\"")     property(name="hostname")
        constant(value="\",\"message\":\"")  property(name="msg" format="json")
        constant(value="\"}")
    }

    *.* action(type="omfwd" target="127.0.0.1" port="601" protocol="tcp"
               template="json-template")

logrotate
----------

.. code-block:: bash

    # /etc/logrotate.d/custom
    /var/log/myapp/*.log {
        daily
        rotate 30
        compress
        delaycompress
        missingok
        notifempty
        create 0640 root adm
        sharedscripts
        postrotate
            systemctl reload myapp > /dev/null 2>&1 || true
        endscript
    }

12.4.3 Vector: The Universal Log Router
=========================================

`Vector <https://vector.dev/>`_ is written in Rust (~10 MB binary, < 50 MB RAM).

File → Parse → Loki Pipeline
-----------------------------

.. code-block:: toml

    # /etc/vector/vector.toml
    [sources.app_logs]
    type = "file"
    include = ["/var/log/myapp/*.log"]
    ignore_older_secs = 600

    [transforms.parse_json]
    type = "remap"
    inputs = ["app_logs"]
    source = '''
    . = parse_json!(.message)
    .timestamp = now()
    .service = "myapp"
    '''

    [sinks.loki]
    type = "loki"
    inputs = ["parse_json"]
    endpoint = "http://loki.example.com:3100"
    encoding.codec = "json"
    labels.service = "{{ service }}"

    [sinks.loki.buffer]
    type = "disk"
    max_size = 1049000000
    when_full = "block"

12.4.4 Grafana Loki: Log Aggregation for the Modern Era
=========================================================

Loki does not index log content — only labels. This reduces storage 5-10x vs ELK.

.. code-block:: yaml

    # loki-config.yaml
    auth_enabled: false
    server:
      http_listen_port: 3100
    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: filesystem
          schema: v13
    storage_config:
      filesystem:
        directory: /loki

Querying with LogQL
--------------------

.. code-block:: text

    # Error count per service in last hour
    sum by (service) (count_over_time({job="myapp"} |= "error" [1h]))
    # Show logs for a specific request
    {job="nginx"} |= "req_abc123"
    # Rate of log lines
    rate({job="postgresql"}[5m])

12.4.5 OpenTelemetry: The Unified Standard
=============================================

`OpenTelemetry <https://opentelemetry.io/>`_ is the industry standard for telemetry.

.. code-block:: yaml

    # /etc/otel/config.yaml
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: "0.0.0.0:4317"
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
    exporters:
      loki:
        endpoint: "http://loki.example.com:3100/loki/api/v1/push"
    service:
      pipelines:
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [loki]

.. important::
   OTel is a **standard**. Instrument once with the OTel SDK, ship anywhere.

12.4.6 Summary
===============

* **rsyslog** and **logrotate** remain essential for local log management.
* **Vector** replaces the ELK pipeline with a single efficient Rust binary.
* **Grafana Loki** replaces Elasticsearch, reducing cost 5-10x.
* **OpenTelemetry** is the universal standard — instrument once, ship anywhere.
