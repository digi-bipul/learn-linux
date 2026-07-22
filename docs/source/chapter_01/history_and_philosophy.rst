.. _history-and-philosophy:

History and Philosophy
======================

Every technology is a fossil — a snapshot of the decisions, constraints,
and values of the people who built it.  To understand *why* Linux feels
the way it does, we must trace its lineage back to the late 1960s, when
a small team at Bell Labs set out to build a simple, elegant operating
system for themselves.

.. contents::
   :local:
   :depth: 1


Unix: The Grandparent (1969–1970s)
------------------------------------

In 1969, Ken Thompson, Dennis Ritchie, and colleagues at AT&T Bell Labs
had a problem.  They had been working on an ambitious time-sharing system
called **Multics**, but the project had grown unwieldy and AT&T
withdrew.  Rather than give up, Thompson found an unused PDP-7 computer
and, in a legendary burst of focused engineering, wrote a stripped-down
operating system in assembly language.  Brian Kernighan half-jokingly
named it **Unics** (as a pun on Multics), and the spelling soon settled
on **Unix**.

Three design decisions made during those early months shaped everything
that followed:

1. **Everything is a file.**  Disks, keyboards, network sockets, even
   running processes expose a file-like interface.  The same ``read()``
   and ``write()`` system calls work on all of them.

2. **Small, composable tools.**  Instead of building monolithic
   applications, Unix provided a toolkit of small programs, each doing
   one thing well.  You connect them with **pipes** (``|``) to solve
   complex problems.

3. **Plain text is the universal interface.**  Configuration files,
   log files, and program output are human-readable text.  This means
   the same tools (``grep``, ``sed``, ``awk``) can inspect, filter, and
   transform anything.

In 1973, Ritchie and Thompson rewrote Unix in the newly invented **C
programming language**.  This was a radical move: until then, operating
systems were written in assembly for a specific machine.  By writing Unix
in C, they made it *portable*.  Unix could now be recompiled for any
hardware with a C compiler — a property that directly foreshadows Linux's
own portability.


The GNU Project: Freedom as a Principle (1983)
-----------------------------------------------

By the early 1980s, Unix had escaped Bell Labs and proliferated into
many proprietary variants — SunOS, HP-UX, AIX, Xenix — each locked behind
commercial licences.  Richard Stallman, a programmer at MIT's Artificial
Intelligence Lab, watched with dismay as the collaborative, open culture
of early computing gave way to closed, proprietary software.

In 1983, Stallman announced the **GNU Project** ("GNU's Not Unix"), with
an audacious goal: create a complete, Unix-compatible operating system
where every line of code was *free* — not free as in price, but free as
in freedom.  He articulated this in the **GNU General Public License
(GPL)**, a legal instrument that uses copyright law to guarantee four
essential freedoms:

.. epigraph::

   * **Freedom 0:** The freedom to run the program as you wish, for any
     purpose.
   * **Freedom 1:** The freedom to study how the program works, and
     change it so it does your computing as you wish.  Access to the
     source code is a precondition for this.
   * **Freedom 2:** The freedom to redistribute copies so you can help
     your neighbour.
   * **Freedom 3:** The freedom to distribute copies of your modified
     versions to others.  By doing this you can give the whole community
     a chance to benefit from your changes.

   — Free Software Foundation, `What is Free Software?
   <https://www.gnu.org/philosophy/free-sw.html>`_

Crucially, the GPL is **copyleft**: anyone who distributes a modified
version of GPL-licensed code must also distribute their modifications
under the same GPL terms.  This ensures that the code *stays* free; it
cannot be taken proprietary downstream.  This legal innovation is the
load-bearing wall of the entire open-source ecosystem.

By 1990, GNU had produced an impressive toolchain — GCC (the GNU Compiler
Collection), glibc, Bash, Emacs, and dozens of core utilities — but it
still lacked a working kernel.  The GNU Hurd (a microkernel) was under
development but years away from being usable.


Linux: The Missing Kernel (1991)
----------------------------------

In 1991, a 21-year-old Finnish computer science student named **Linus
Torvalds** bought an Intel 386 PC and was frustrated with MINIX, a
small teaching operating system created by Andrew Tanenbaum.  MINIX was
designed for education, not serious use, and its licence restricted
redistribution.

Torvalds began writing a terminal emulator so he could dial into his
university's Unix systems.  That terminal emulator needed to read and
write the disk.  It needed a filesystem driver.  It needed a task
switcher.  Before long, Torvalds was not writing a terminal emulator at
all — he was writing a kernel.

On 25 August 1991, he posted the now-famous message to the
``comp.os.minix`` newsgroup:

.. code-block:: text

   Hello everybody out there using minix —

   I'm doing a (free) operating system (just a hobby, won't be big and
   professional like gnu) for 386(486) AT clones.  This has been brewing
   since april, and is starting to get ready.  I'd like any feedback on
   things people like/dislike in minix, as my OS resembles it somewhat
   ...

The "hobby" kernel was released under the GPL, and a global community of
developers coalesced around it with astonishing speed.  By combining the
Linux kernel with the GNU userspace, a complete, free operating system
was finally available — and it arrived just as the World Wide Web was
taking off, accelerating its adoption through online collaboration.


The Unix Philosophy in Practice
---------------------------------

The design ethos inherited from Unix permeates Linux at every level.  It
can be distilled into a few memorable rules:

.. rubric:: Rule 1: Do One Thing Well

Each program should have a single, clear responsibility.  ``cat``
concatenates files.  ``sort`` sorts lines.  ``uniq`` removes duplicates.
None of these programs tries to do the others' job.  When you need to
count unique lines in a file, you *combine* them:

.. code-block:: bash

   $ sort data.txt | uniq | wc -l

No single program needed to know about counting; you composed the
solution from simpler parts.

.. rubric:: Rule 2: Expect Output to Become Input

Programs should produce plain-text output that other programs can
consume.  This is why most Unix commands print one "record" per line and
use whitespace as a field delimiter.  It is also why programs that
produce "pretty" human-formatted output (with boxes and columns) usually
provide a machine-parseable alternative (e.g., ``ls -1`` for one entry
per line).

.. rubric:: Rule 3: Prototype, Then Polish

The Unix culture favours building a working — even if crude — version
quickly, then iterating.  This is reflected in Linux itself: the first
public release (0.01) was barely functional, but it was *released*,
attracting testers and contributors who accelerated its development far
beyond what any single person could achieve.

.. rubric:: Rule 4: Leverage the Community

Linux development is radically transparent.  The entire kernel source
tree is publicly visible.  Discussions happen on mailing lists archived
forever.  Anyone can submit a patch.  This "many eyeballs" approach —
what Eric Raymond called **"Linus's Law"** in his essay *The Cathedral
and the Bazaar* — makes bugs shallow and innovation rapid.


The Landscape Today (2026)
----------------------------

.. sidebar:: Key Milestones

   =====  ===========================================
   1969   Unix born at Bell Labs
   1973   Unix rewritten in C
   1983   GNU Project announced
   1991   Linux kernel 0.01 released
   1993   Debian, Slackware founded
   1994   Linux 1.0; Red Hat founded
   2004   Ubuntu 4.10 released
   2011   Linux 3.0; Android dominates mobile
   2015   Linux 4.0; containers (Docker) go mainstream
   2020   Linux 5.0; >27M lines of code
   2026   Linux 6.x; RISC-V matures; 90%+ cloud share
   =====  ===========================================

Linux is no longer a scrappy underdog.  It is the default operating
system of the internet.  But its culture retains the values of its
ancestors: transparency, modularity, and a deep respect for the user's
freedom to understand and modify their own tools.

In :ref:`choosing-a-distribution`, we turn from history to the practical
question: *which Linux should I install?*
