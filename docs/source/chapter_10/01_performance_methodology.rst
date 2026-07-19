.. _ch10-perf-methodology:

###########################################################
10.1  Performance Methodology
###########################################################

.. epigraph::

   "It is not enough to have a good mind. The main thing is to use it well."
   — René Descartes

Performance analysis without a methodology is cargo-cult sysadmin. You run
``top``, you see a high number, you reboot. The modern Site Reliability
Engineer does not guess. They apply a structured framework — the **scientific
method to production systems** — and they do so with quantitative rigour.

In this section, we build the mental scaffolding for every tool invocation in
the rest of this chapter. We cover the three dominant methodologies in use
today (USE, RED, and the Four Golden Signals), and we develop the mathematical
intuition behind latency, throughput, and utilisation.

----------------------------------------------------------------------
10.1.1  The Scientific Method Applied to Systems
----------------------------------------------------------------------

Before we discuss any specific methodology, we must internalise a single
principle: **every performance problem is a hypothesis to be tested.** The
scientific method for systems performance proceeds as follows:

#. **Observe** a symptom (e.g., "the web API returns 503 errors under load").
#. **Form a hypothesis** (e.g., "the connection pool to the database is
   exhausted").
#. **Collect data** to test the hypothesis (e.g., measure active connections
   via ``ss -s``, ``nstat``, or a metrics dashboard).
#. **Analyse** the data. Does it support or refute the hypothesis?
#. **Act** (e.g., increase the pool size, throttle requests, or fix a leak).
#. **Return to step 1** to confirm the intervention worked.

This loop is the beating heart of Site Reliability Engineering. Every tool
taught in this chapter serves steps 3 and 4. Without the loop, you have
noise. With it, you have diagnosis.

----------------------------------------------------------------------
10.1.2  The USE Method (For Resources)
----------------------------------------------------------------------

The **USE Method** — **U**tilisation, **S**aturation, **E**rors — was
formalised by Brendan Gregg in 2013. It is the single most effective
framework for **resource** analysis. A *resource* is any physical or virtual
component of a system: CPU cores, memory DIMMs, disk drives, network
interfaces, locks, and caches.

For every resource, ask three questions:

+----------------+--------------------------------------------------+---------------------------------+
| **Metric**     | **Question**                                      | **Example (CPU)**               |
+================+==================================================+=================================+
| Utilisation    | How busy is the resource? (average over time)     | CPU utilisation at 95%          |
+----------------+--------------------------------------------------+---------------------------------+
| Saturation     | How much extra work is queued? (excess demand)    | Load average / run queue depth  |
+----------------+--------------------------------------------------+---------------------------------+
| Errors         | Are any operations failing?                       | CPU cache errors, machine checks|
+----------------+--------------------------------------------------+---------------------------------+

**Utilisation** is defined as:

.. math::

   U = \frac{B}{T}

where :math:`B` is the time the resource was busy and :math:`T` is the total
observation interval. For resources that serve requests concurrently (like a
multi-core CPU), utilisation is the proportion of time *at least one unit* was
busy. For resources that serve one request at a time (like a single disk
spindle), it is the proportion of time the device was doing work.

**Saturation** is the degree to which the resource has more work to do than it
can process. It manifests as a **queue**. For CPU, the run queue length (tasks
waiting for a core) is the saturation metric. For network, buffer occupancy is
saturation.

**Errors** are mission-critical. A resource at high utilisation with zero
errors may be acceptable to the business. A resource at 10% utilisation with
errors is a fire.

.. admonition:: Why USE over "top"?
   :class: tip

   ``top`` shows CPU utilisation, but it buries saturation (load average) and
   errors. The USE method forces you to check *all three* for *every*
   resource, systematically. This prevents blind spots.

----------------------------------------------------------------------
10.1.3  The RED Method (For Services)
----------------------------------------------------------------------

While USE targets **resources**, the **RED Method** — **R**ate, **E**rrors,
**D**uration — targets **services**. Coined by Tom Wilkie (Grafana Labs), RED
applies the same triadic approach but to request-serving components (e.g., an
API server, a database proxy, a message queue):

+----------------+--------------------------------------------------+
| **Metric**     | **Question**                                      |
+================+==================================================+
| Rate           | How many requests per second is this service      |
|                | receiving?                                       |
+----------------+--------------------------------------------------+
| Errors         | How many of those requests are failing?           |
|                | (HTTP 5xx, exceptions, timeouts)                  |
+----------------+--------------------------------------------------+
| Duration       | How long do successful requests take?             |
|                | (latency distribution, e.g., p50, p99)            |
+----------------+--------------------------------------------------+

The RED method is *derived* from the Four Golden Signals (see below) but
collapses them into three actionable numbers that every service owner can
memorise. It maps naturally to Prometheus and OpenTelemetry metrics:

.. code-block:: promql

   # Rate of requests
   rate(http_requests_total[5m])

   # Error ratio
   rate(http_requests_total{status=~"5.."}[5m]) /
     rate(http_requests_total[5m])

   # Latency p99
   histogram_quantile(0.99,
     rate(http_request_duration_seconds_bucket[5m]))

----------------------------------------------------------------------
10.1.4  The Four Golden Signals
----------------------------------------------------------------------

The **Four Golden Signals** were defined by Google in the *Site Reliability
Engineering* book (2016). They are a superset of RED and form the foundation
of any production-monitoring strategy:

#. **Latency:** The time it takes to service a request. Distinguish between
   *slow* and *failing*. A high-latency proxy that retries on failure can mask
   errors and inflate latency — tail latencies (p99, p999) reveal this.
#. **Traffic:** The demand on the system. Measured in HTTP requests/second,
   queries per second (QPS), active connections, or network throughput.
#. **Errors:** Explicit failures (HTTP 5xx, timeouts) and implicit failures
   (success but wrong answer, or success but high latency).
#. **Saturation:** How "full" the service is. This is the USE saturation
   metric applied to service capacity. Often measured as a fraction of the
   maximum concurrency the service can handle.

.. note::

   The Four Golden Signals do not mandate *what* to measure — they mandate
   *which categories* of measurement matter. Prometheus exporters and
   OpenTelemetry SDKs are designed to emit these categories by default.

----------------------------------------------------------------------
10.1.5  Latency vs. Throughput — The Mathematics
----------------------------------------------------------------------

A deep understanding of the relationship between **latency** and **throughput**
is what separates a script-runner from an engineer.

**Throughput** (X) is the rate at which requests are completed:

.. math::

   X = \frac{C}{T}

where :math:`C` is the number of completions and :math:`T` is the observation
window.

**Latency** (R) is the residence time of a single request — the time between
submission and completion.

**Little's Law**, arguably the single most important equation in queueing
theory, relates the two:

.. math::

   N = X \cdot R

where :math:`N` is the **average number of requests in the system** (in-flight
or queued). This is a law, not a heuristic — it holds for any stable system.

**Why Little's Law matters in practice:**

- If you measure throughput and latency, you can deduce the average concurrency
  in your system.
- If you want to reduce latency (R) while maintaining throughput (X), you must
  reduce concurrency (N) — usually by adding capacity (horizontal scaling) or
  optimising serialisation.

**Tail latency.** In a distributed system, the *slowest* response determines
user-perceived responsiveness. Modern systems are optimised for **p99**
latency — the latency below which 99% of requests fall. If your p99 latency
is 500 ms and your p50 is 10 ms, 1% of your users experience a 50× slowdown.
Techniques like hedging, request coalescing, and eager termination mitigate
this.

**The utilisation-latency curve.** As utilisation approaches 100%, latency
grows hyperbolically (not linearly). For an M/M/1 queue:

.. math::

   R = \frac{S}{1 - U}

where :math:`S` is the service time and :math:`U` is utilisation. At
:math:`U = 0.5`, latency is :math:`2S` (double the service time). At
:math:`U = 0.9`, latency is :math:`10S`. At :math:`U = 0.99`, latency is
:math:`100S`. **Running any resource above ~70% utilisation without a latency
budget is a recipe for disaster.** This is why SREs set utilisation targets
well below 100%.

----------------------------------------------------------------------
10.1.6  Summary
----------------------------------------------------------------------

+---------------------------+----------------------------------------------+
| Framework                 | Best for                                     |
+===========================+==============================================+
| USE Method                | Hardware and kernel resources (CPU, memory,  |
|                           | disk, network interfaces)                    |
+---------------------------+----------------------------------------------+
| RED Method                | Application services (HTTP APIs, gRPC,       |
|                           | message queues)                              |
+---------------------------+----------------------------------------------+
| Four Golden Signals       | Any production service; the "default" set    |
|                           | for monitoring strategy                      |
+---------------------------+----------------------------------------------+

In the sections that follow, we apply these methodologies using modern
Linux tools. Every ``iostat`` invocation, every ``perf`` command, every
``bpftrace`` one-liner — they all serve the goal of answering the USE or RED
questions.

**Further Reading:**

- Brendan Gregg, *Systems Performance: Enterprise and the Cloud*, 2nd Edition
  (Addison-Wesley, 2021).
- Google SRE Team, *Site Reliability Engineering* (O'Reilly, 2016), ch. 6
  ("Monitoring Distributed Systems").
- Tom Wilkie, "Service RED method" (Grafana Labs blog).
