.. _ch10-observability-stack:

###########################################################
The Modern Observability Stack
###########################################################

.. epigraph::

   "Monitoring tells you whether the system is working. Observability means
   you can ask arbitrary questions about it without having to ship new code."
   — Charity Majors (Honeycomb)

The difference between *monitoring* and *observability* is the difference
between a checklist and a laboratory. Monitoring asks predefined questions.
Observability lets you ask *novel* questions at 3 AM when the predefined
dashboard shows nothing wrong but users are screaming.

The modern observability stack — Prometheus + Grafana + OpenTelemetry — has
coalesced as the industry standard by 2026.

----------------------------------------------------------------------
The Architectural Shift: Monoliths to Distributed Telemetry
----------------------------------------------------------------------

**The legacy model (pre-2015):** Nagios, Zabbix — a single server polling via
SSH/SNMP every 5 minutes. Fixed schema. Did not scale beyond ~10k metrics.

**The modern model (2026):**

- **Pull-based metrics:** Prometheus scrapes targets. No SSH. No phoning home.
- **Multi-dimensional data:** Metric names + key-value **labels** enable
  slicing and aggregation without schema changes.
- **Three pillars unified:** OpenTelemetry emits metrics, logs, and traces
  through a single SDK.

----------------------------------------------------------------------
Prometheus: Metrics That Answer Questions
----------------------------------------------------------------------

**Data model:**

.. code-block:: text

   node_cpu_seconds_total{cpu="0",mode="user"} 12345.67
   node_cpu_seconds_total{cpu="0",mode="system"} 6789.12

**Metric types:**

+-------------+------------------------------------------------+---------------------------+
| Type        | Description                                    | Example                   |
+=============+================================================+===========================+
| **Counter** | Monotonically increasing. Use ``rate()``.      | ``http_requests_total``   |
+-------------+------------------------------------------------+---------------------------+
| **Gauge**   | Goes up and down.                              | ``node_memory_usage_bytes``|
+-------------+------------------------------------------------+---------------------------+
| **Histogram**| Samples into buckets; enables p50/p99.        | ``_bucket{le="0.1"}``     |
+-------------+------------------------------------------------+---------------------------+

**Installing and running:**

.. code-block:: console

   # Node Exporter
   $ /opt/node_exporter/node_exporter --web.listen-address=":9100" &

   # prometheus.yml
   global:
     scrape_interval: 15s
   scrape_configs:
     - job_name: 'node'
       static_configs:
         - targets: ['localhost:9100']

   $ /opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml &

**PromQL queries:**

.. code-block:: promql

   # CPU utilisation per mode
   rate(node_cpu_seconds_total{mode="user"}[5m])

   # Memory utilisation percentage
   (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

   # Disk write latency
   rate(node_disk_write_time_seconds_total[5m]) /
     rate(node_disk_writes_completed_total[5m]) * 1000

   # p95 HTTP latency
   histogram_quantile(0.95,
     rate(http_request_duration_seconds_bucket[5m]))

**Recording rules** precompute expensive queries:

.. code-block:: yaml

   groups:
     - name: node_rules
       rules:
         - record: node:memory_utilization
           expr: 1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes

----------------------------------------------------------------------
Grafana: From Metrics to Meaning
----------------------------------------------------------------------

.. code-block:: console

   $ apt install grafana
   $ systemctl start grafana-server
   # Login at http://localhost:3000 (admin/admin)

Build **USE dashboards** — one panel per resource for Utilisation, Saturation,
Errors. Annotate deployments via the HTTP API:

.. code-block:: console

   $ curl -X POST http://admin:password@localhost:3000/api/annotations \
       -H "Content-Type: application/json" \
       -d '{"dashboardUID":"abc123","text":"Deploy v2.3.1","tags":["deploy"]}'

----------------------------------------------------------------------
OpenTelemetry: The Unified Standard
----------------------------------------------------------------------

**OpenTelemetry (OTel)** is the CNCF project that unified metrics, logs, and
traces under a single standard. It replaced fragmented vendor agents (DataDog,
New Relic, Honeycomb, Jaeger — each with their own SDK).

**The OTel Pipeline:**

::

   [Application (OTel SDK)]  -->  [OTel Collector]  -->  Prometheus (metrics)
                                                   -->  Tempo (traces)
                                                   -->  Loki (logs)

**The OTel Collector configuration:**

.. code-block:: yaml

   receivers:
     otlp:
       protocols:
         grpc:
           endpoint: 0.0.0.0:4317
   processors:
     batch:
       timeout: 1s
   exporters:
     prometheus:
       endpoint: "0.0.0.0:8889"
   service:
     pipelines:
       metrics:
         receivers: [otlp]
         processors: [batch]
         exporters: [prometheus]

**Three-signal correlation:**

A log line contains a ``traceID``. Click it → opens the trace in Tempo →
shows the span tree → click a span → see the exact line of code and the
metric at that moment.

----------------------------------------------------------------------
The Complete Stack (Deploy in Under an Hour)
----------------------------------------------------------------------

For a production-grade self-hosted stack:

.. code-block:: console

   # 1. Node Exporter on every host
   $ ./node_exporter &

   # 2. Prometheus on the monitoring node
   $ ./prometheus --config.file=prometheus.yml &

   # 3. OTel Collector (receives app telemetry)
   $ otelcol --config otel-config.yaml &

   # 4. Grafana (visualisation)
   $ systemctl start grafana-server

**Resource estimate (100-node cluster):**

+------------------+----------------+-------------------+------------------+
| Component        | CPU (cores)    | Memory (GB)       | Storage (GB/day) |
+==================+================+===================+==================+
| Prometheus       | 2              | 4                 | 10               |
+------------------+----------------+-------------------+------------------+
| OTel Collector   | 1              | 2                 | 0 (transient)    |
+------------------+----------------+-------------------+------------------+
| Grafana          | 1              | 1                 | 1                |
+------------------+----------------+-------------------+------------------+

----------------------------------------------------------------------
Alerting: When to Wake Someone
----------------------------------------------------------------------

**Alert on symptoms, not causes.** "HTTP 5xx > 1%" is a symptom. "CPU > 80%"
is a cause.

.. code-block:: yaml

   groups:
     - name: node_alerts
       rules:
         - alert: NodeCPUUsageHigh
           expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
           for: 5m
           labels:
             severity: warning
           annotations:
             summary: "Instance {{ $labels.instance }} CPU > 80%"

**Every alert must have a runbook** containing: which dashboard to open, which
``perf`` command to run, which eBPF tool to invoke, and the mitigation steps.

----------------------------------------------------------------------
Observability USE/RED Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Prometheus: query the four golden signals
   $ promtool query instant 'rate(http_requests_total[5m])'
   $ promtool query instant 'rate(http_requests_total{status=~"5.."}[5m])'
   $ promtool query instant 'histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))'

   # 2. Node Exporter: host-level USE
   $ promtool query instant 'node_cpu_seconds_total{mode="idle"}'
   $ promtool query instant 'node_memory_Available_bytes'

   # 3. Grafana: RED dashboard for each service

   # 4. OpenTelemetry: check collector health
   $ curl http://localhost:13133/health

   # 5. Alertmanager: check active alerts
   $ curl http://localhost:9093/api/v1/alerts

----------------------------------------------------------------------
Summary
----------------------------------------------------------------------

+---------------------+--------------------------------------------------+
| Component           | Purpose                                          |
+=====================+==================================================+
| **Prometheus**      | Pull-based metrics store and query engine.       |
+---------------------+--------------------------------------------------+
| **Node Exporter**   | Host-level metrics (CPU, memory, disk, network). |
+---------------------+--------------------------------------------------+
| **Grafana**         | Dashboards, visualisations, alerting UI.         |
+---------------------+--------------------------------------------------+
| **OpenTelemetry**   | Unified instrumentation SDK + collector.         |
+---------------------+--------------------------------------------------+
| **Loki**            | Log aggregation (same labels as Prometheus).     |
+---------------------+--------------------------------------------------+
| **Tempo**           | Trace storage (scalable, cost-efficient).        |
+---------------------+--------------------------------------------------+

With Prometheus providing high-resolution metrics, OpenTelemetry unifying
instrumentation, and Grafana connecting all the dots, the SRE of 2026 does not
ask "is the system up?" — they ask "what happened at 14:23 UTC when throughput
dropped by 12% and the p99 latency doubled?" And the observability stack can
answer them.

**Further Reading:**

- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- OpenTelemetry Documentation: https://opentelemetry.io/docs/
- Google SRE Book, ch. 6: "Monitoring Distributed Systems"
- *The Art of Monitoring* by James Turnbull
