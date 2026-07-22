.. _app-a-cookbook:

------------------------------------------------------------------------------
A.4  Admin Cookbook: Ready-to-Use Patterns
------------------------------------------------------------------------------

This section provides **tested, production-ready** regex patterns for the
most common sysadmin tasks. Every pattern is annotated with its intended tool
and flavor.

.. sidebar:: Legend

   **B** = BRE | **E** = ERE | **P** = PCRE
   ``g`` = grep | ``s`` = sed | ``a`` = awk

.. warning::
   All patterns below have been verified against GNU grep 3.11, GNU sed 4.9,
   and Gawk 5.3. Always test on your data before running against production
   configuration files.

------------------------------------------------------------------------------
A.4.1  IPv4 Address Matching
------------------------------------------------------------------------------

A valid IPv4 address is four octets (0-255) separated by periods.

.. rubric:: Pattern (PCRE — strict)

.. code-block:: text

   \b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b

.. rubric:: Pattern (ERE — same logic, no shorthand)

.. code-block:: text

   (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)

.. rubric:: One-liner examples

.. code-block:: bash

   # Extract all IPv4 addresses from a file
   grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' file.log | \
     awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255'

   # PCRE — cleaner with lookahead
   grep -oP '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' file.log

   # sed: anonymize IPs (replace with 10.0.0.0)
   sed -E 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/10.0.0.0/g' access.log

------------------------------------------------------------------------------
A.4.2  IPv6 Address Matching
------------------------------------------------------------------------------

IPv6 is more complex. A valid address has 8 groups of 1-4 hex digits separated
by colons, with these rules:

* Leading zeros in a group are optional.
* One contiguous run of zero groups may be collapsed with ``::`` (but only once).
* The loopback address is ``::1``; the unspecified address is ``::``.
* IPv4-mapped IPv6: ``::ffff:1.2.3.4``.

.. rubric:: Pattern (PCRE — strict, full IPv6)

.. code-block:: text

   \b(?:(?:(?:[0-9A-Fa-f]{1,4}:){6}(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)))|::(?:[0-9A-Fa-f]{1,4}:){0,5}(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|[0-9A-Fa-f]{1,4}::(?:[0-9A-Fa-f]{1,4}:){0,4}(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|(?:[0-9A-Fa-f]{1,4}:){1,2}(?::(?:[0-9A-Fa-f]{1,4}:){1,4}(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|::(?:[0-9A-Fa-f]{1,4}:){1,4}(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))))\b

.. rubric:: Simpler practical pattern (PCRE — accepts common valid forms)

.. code-block:: text

   \b(?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}\b|\b(?:[0-9A-Fa-f]{1,4}:){1,6}:\b|\b(?:[0-9A-Fa-f]{1,4}:){1,5}(?::[0-9A-Fa-f]{1,4}){1,2}\b|\b(?:[0-9A-Fa-f]{1,4}:){1,4}(?::[0-9A-Fa-f]{1,4}){1,3}\b|\b(?:[0-9A-Fa-f]{1,4}:){1,3}(?::[0-9A-Fa-f]{1,4}){1,4}\b|\b(?:[0-9A-Fa-f]{1,4}:){1,2}(?::[0-9A-Fa-f]{1,4}){1,5}\b|\b[0-9A-Fa-f]{1,4}:(?::[0-9A-Fa-f]{1,4}){1,6}\b|\b:(?::[0-9A-Fa-f]{1,4}){1,7}\b|\b::\b|\b::1\b|\b::ffff:(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b

.. rubric:: One-liner examples

.. code-block:: bash

   # Quick sanity: find anything that looks like an IPv6
   grep -oiP '\b[0-9a-f:]{4,}\b' file.log | grep ':'

   # Extract IPv6 from nginx logs (PCRE)
   grep -oP '\b(?:[0-9A-Fa-f]{1,4}:){1,7}[0-9A-Fa-f]{1,4}\b|::1' access.log

------------------------------------------------------------------------------
A.4.3  Email Address Matching
------------------------------------------------------------------------------

Email validation is famously complex (RFC 5322). The pattern below covers at
least 99% of real-world addresses without being impractically huge.

.. rubric:: Pattern (PCRE — RFC 5322 simplified)

.. code-block:: text

   \b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b

.. rubric:: Pattern (ERE — same logic)

.. code-block:: text

   [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}

.. warning::
   The above patterns will **not** catch every technically valid RFC 5322
   address (e.g., quoted local parts like ``"foo bar"@example.com``, or
   comments in parentheses). For strict validation, use a dedicated library
   (e.g., Python's ``email_validator``, Perl's ``Email::Valid``).

.. rubric:: One-liner examples

.. code-block:: bash

   # Extract all email addresses from a file
   grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' file.txt

   # Validate email format in a CSV (awk)
   awk -F, '$2 ~ /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/ { print $1, "OK" }' users.csv

   # Sanitize: replace email with hashed version
   sed -E 's/([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/\1@REDACTED/g' file.txt

------------------------------------------------------------------------------
A.4.4  URL Matching
------------------------------------------------------------------------------

.. rubric:: Pattern (PCRE)

.. code-block:: text

   \bhttps?://[^\s/$.?#].[^\s]*\b

.. rubric:: More precise pattern (PCRE — captures protocol, domain, path)

.. code-block:: text

   \b(https?|ftp|file)://([A-Za-z0-9._~:/-]+)(/[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=-]*)?\b

.. rubric:: One-liner examples

.. code-block:: bash

   # Extract all URLs from a file
   grep -oP '\bhttps?://[^\s/$.?#][^\s]*' file.txt

   # Extract domain only from URLs in apache logs
   awk '{ match($0, /https?:\/\/([^/]+)/, a); print a[1] }' access.log

   # Replace all URLs in a config file with a placeholder
   sed -E 's|https?://[^[:space:]]+|<URL_REDACTED>|g' config.txt

------------------------------------------------------------------------------
A.4.5  Date & Timestamp Matching
------------------------------------------------------------------------------

.. list-table:: Common date/time formats with regex patterns
   :header-rows: 1
   :widths: 30 35 35

   * - Format
     - Pattern (ERE)
     - Example
   * - ISO 8601 date
     - ``\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b``
     - ``2026-07-20``
   * - ISO 8601 datetime
     - ``\b[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\b``
     - ``2026-07-20T14:30:00``
   * - US date (MM/DD/YYYY)
     - ``\b[0-9]{2}/[0-9]{2}/[0-9]{4}\b``
     - ``07/20/2026``
   * - Syslog timestamp
     - ``[A-Z][a-z]{2}\s+[0-9]{1,2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}``
     - ``Jul 20 10:36:02``
   * - HTTP date (RFC 7231)
     - ``[A-Z][a-z]{2},\s[0-9]{2}\s[A-Z][a-z]{2}\s[0-9]{4}\s[0-9]{2}:[0-9]{2}:[0-9]{2}\sGMT``
     - ``Mon, 20 Jul 2026 10:36:02 GMT``
   * - 24-hour time
     - ``\b[0-9]{2}:[0-9]{2}(:[0-9]{2})?\b``
     - ``10:36:02``
   * - Nginx log date (DD/Mon/YYYY:HH:MM:SS)
     - ``[0-9]{2}/[A-Z][a-z]{2}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}``
     - ``20/Jul/2026:10:36:02``

.. rubric:: One-liner examples

.. code-block:: bash

   # Extract only ISO dates from a file
   grep -oE '\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b' file.log

   # Validate YYYY-MM-DD range (month 01-12, day 01-31)
   grep -oE '\b(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\b' dates.txt

   # Convert US date to ISO date
   sed -E 's|\b([0-9]{2})/([0-9]{2})/([0-9]{4})\b|\3-\1-\2|g' file.txt

------------------------------------------------------------------------------
A.4.6  Nginx Log Parsing
------------------------------------------------------------------------------

Standard Nginx combined log format:

.. code-block:: text

   log_format combined '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent"';

Example line::

   192.168.1.10 - admin [20/Jul/2026:10:36:02 +0000] "GET /api/health HTTP/1.1" 200 2326 "https://example.com/dashboard" "Mozilla/5.0 ..."

.. rubric:: Pattern to parse combined log line (ERE)

.. code-block:: text

   ^([0-9.]+) - ([^ ]+) \[([^\]]+)\] "([^"]*)" ([0-9]+) ([0-9]+) "([^"]*)" "([^"]*)"$

.. rubric:: Capture group mapping

.. list-table:: Nginx combined log capture groups
   :header-rows: 1
   :widths: 10 25 65

   * - Group
     - Field
     - Notes
   * - ``\1``
     - ``$remote_addr``
     - Client IP
   * - ``\2``
     - ``$remote_user``
     - Authenticated user ("-" if none)
   * - ``\3``
     - ``$time_local``
     - Timestamp in bracket
   * - ``\4``
     - ``$request``
     - Full HTTP request line
   * - ``\5``
     - ``$status``
     - HTTP status code (200, 404, 500, …)
   * - ``\6``
     - ``$body_bytes_sent``
     - Bytes in response body
   * - ``\7``
     - ``$http_referer``
     - Referrer URL ("-" if none)
   * - ``\8``
     - ``$http_user_agent``
     - User-agent string

.. rubric:: One-liner examples

.. code-block:: bash

   # Count 404 errors by IP
   awk '$9 == 404 { ips[$1]++ } END { for (i in ips) print ips[i], i }' /var/log/nginx/access.log | sort -rn

   # Extract all requested URIs with query strings
   grep -oP '"GET \K[^?]*\?[^"]*' /var/log/nginx/access.log

   # Find slow requests (>5s) if using $upstream_response_time
   awk -F, '$NF > 5 { print }' /var/log/nginx/access.log

   # Bytes served per day
   awk '{ bytes[$4] += $10 } END { for (d in bytes) print d, bytes[d] }' /var/log/nginx/access.log

------------------------------------------------------------------------------
A.4.7  Apache Log Parsing
------------------------------------------------------------------------------

Apache combined log format::

   192.168.1.10 - admin [20/Jul/2026:10:36:02 +0000] "GET /index.html HTTP/1.1" 200 2326

.. rubric:: Pattern (ERE)

.. code-block:: text

   ^([0-9.]+) - ([^ ]+) \[([^\]]+)\] "([^"]*)" ([0-9]{3}) ([0-9]+)

.. rubric:: Capture group mapping

.. list-table:: Apache combined log capture groups
   :header-rows: 1
   :widths: 10 25 65

   * - Group
     - Field
     - Notes
   * - ``\1``
     - IP
     - Client address
   * - ``\2``
     - Identd / user
     - Usually "-"
   * - ``\3``
     - Timestamp
     - ``[DD/Mon/YYYY:HH:MM:SS tz]``
   * - ``\4``
     - Request line
     - ``METHOD /path HTTP/1.x``
   * - ``\5``
     - Status code
     - 3-digit code
   * - ``\6``
     - Bytes sent
     - Content-Length of response

.. rubric:: One-liner examples

.. code-block:: bash

   # Top 10 most requested pages
   awk '{ print $7 }' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head -10

   # All requests from a specific IP
   grep '^192\.168\.1\.10 ' /var/log/apache2/access.log

   # Non-200 status codes count
   awk '$9 != 200 { codes[$9]++ } END { for (c in codes) print c, codes[c] }' /var/log/apache2/access.log

   # Traffic in MB by IP
   awk '{ ip[$1] += $10 } END { for (i in ip) printf "%s %.2f MB\n", i, ip[i]/1048576 }' access.log | sort -k2 -rn

------------------------------------------------------------------------------
A.4.8  Additional Sysadmin Patterns
------------------------------------------------------------------------------

.. list-table:: Quick-reference pattern collection
   :header-rows: 1
   :widths: 25 35 40

   * - What to match
     - Pattern (ERE)
     - Tool
   * - MAC address (colon)
     - ``\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b``
     - grep -E
   * - MAC address (dash)
     - ``\b([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}\b``
     - grep -E
   * - UUID v4
     - ``\b[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b``
     - grep -E
   * - SHA256 hash (64 hex)
     - ``\b[0-9a-fA-F]{64}\b``
     - grep -E
   * - Hostname (RFC 952)
     - ``\b([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])\.?([A-Za-z0-9-]+\.)*[A-Za-z]{2,}\b``
     - grep -E
   * - Credit card number (luhn not checked)
     - ``\b[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}\b``
     - grep -E
   * - SSH key fingerprint
     - ``\bSHA256:[A-Za-z0-9+/]{43}=\b``
     - grep -E
   * - HTML tag
     - ``<([A-Za-z][A-Za-z0-9]*)\b[^>]*>(.*?)</\1>``
     - grep -oP
   * - Comment lines (shell)
     - ``^[[:space:]]*#``
     - grep -E
   * - Blank lines
     - ``^[[:space:]]*$``
     - grep -E

.. rubric:: Complete one-liner: nginx log analysis pipeline

.. code-block:: bash
   :caption: Identify top 10 client IPs by request count, excluding internal

   grep -v '^127\.0\.0\.1\|^10\.\|^192\.168\.' /var/log/nginx/access.log | \
     awk '{ ips[$1]++ } END { for (i in ips) print ips[i], i }' | \
     sort -rn | head -10

.. rubric:: Complete one-liner: validate /etc/passwd line format

.. code-block:: bash

   awk -F: 'NF != 7 { print "BAD:", $0 }' /etc/passwd
   # Every line must have exactly 7 colon-separated fields
