I/O Redirection & Pipelines
===========================================

.. sidebar:: In This Section

   * stdin, stdout, stderr — the three standard streams
   * ``>``, ``>>``, ``<``, ``2>``, ``2>&1``, ``&>``
   * Pipelines (``|``) and the Unix philosophy
   * ``tee``, process substitution, named pipes (FIFOs)
   * Here documents and here strings

---

If the shell is the workshop, then I/O redirection is the conveyor belt that
moves data between machines. This section explains the fundamental mechanism
by which Unix processes communicate: file descriptors.

.. _file-descriptors:

The Three Standard Streams
============================

Every process in Unix is born with three open **file descriptors** (FDs) —
integer handles that the kernel uses to identify open files, sockets, or pipes:

.. list-table::
   :header-rows: 1
   :widths: 5 15 15 65

   * - FD
     - Name
     - Symbolic Constant
     - Purpose
   * - 0
     - **stdin** (standard input)
     - ``STDIN_FILENO``
     - The default source of input. By default, connected to the keyboard.
   * - 1
     - **stdout** (standard output)
     - ``STDOUT_FILENO``
     - The default destination for normal program output.
   * - 2
     - **stderr** (standard error)
     - ``STDERR_FILENO``
     - The default destination for diagnostic and error messages.

This separation is one of Unix's most elegant design decisions: **normal output
and error messages travel through different channels**, so you can capture
results without losing diagnostics.

.. code-block:: bash

    $ ls /existing /nonexistent
    ls: cannot access '/nonexistent': No such file or directory   # stderr
    /existing:                                                     # stdout

    $ ls /existing /nonexistent > output.txt
    ls: cannot access '/nonexistent': No such file or directory   # stderr (still visible)
    $ cat output.txt
    /existing                                                      # stdout (captured)

In the example above, ``> output.txt`` redirects only **file descriptor 1**
(stdout). The error message goes to stderr (FD 2), which still points to the
terminal, so you see it.

.. _redirection-operators:

Redirection Operators in Detail
=================================

Output Redirection: ``>`` and ``>>``
--------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Syntax
     - Behaviour
   * - ``cmd > file``
     - Redirect stdout to ``file``. **Creates or truncates** ``file``.
   * - ``cmd >> file``
     - Redirect stdout to ``file``. **Creates or appends** to ``file``.

.. code-block:: bash

    $ echo "first line"  >  out.txt     # create/truncate
    $ echo "second line" >  out.txt     # truncates: only "second line" remains
    $ echo "third line"  >> out.txt     # appends: both lines now present
    $ cat out.txt
    second line
    third line

.. warning::

   ``>`` truncates the file **before** the command runs. If you redirect
   ``cat file.txt > file.txt``, the shell opens ``file.txt`` for writing
   (truncating it to zero bytes) *before* ``cat`` gets to read it, resulting in
   an empty file. Use ``sponge`` (from moreutils) or a temporary file for
   in-place operations.

Input Redirection: ``<``
--------------------------

.. code-block:: bash

    $ wc -l < /etc/passwd          # count lines; filename not shown
    47

    $ wc -l /etc/passwd            # compare: filename is shown
    47 /etc/passwd

When you use ``<``, the program receives the file's content on stdin. Many
programs behave subtly differently when reading from stdin versus a named file
— ``wc`` omits the filename, ``grep`` may buffer differently.

Error Redirection
-------------------

.. code-block:: bash

    $ cmd 2> errors.log           # redirect stderr (FD 2) to file
    $ cmd 2>> errors.log          # append stderr

    # Redirect stdout and stderr to different files:
    $ cmd > output.log 2> error.log

.. _merging-streams:

Merging stdout and stderr: ``2>&1``
-------------------------------------

This is the most misunderstood operator in the shell. ``2>&1`` means:
**"make file descriptor 2 point to whatever file descriptor 1 currently points
to."** It is *not* "redirect stderr to stdout"; it is a file descriptor
duplication at the system call level.

.. code-block:: bash

    # Capture BOTH stdout and stderr in one file:
    $ cmd > output.log 2>&1

.. important::

   **Order matters.** The shell processes redirections left to right:

   .. code-block:: bash

       $ cmd 2>&1 > output.log    # WRONG: stderr goes to ORIGINAL stdout (terminal),
                                   # then stdout is redirected to file

       $ cmd > output.log 2>&1    # CORRECT: stdout goes to file, then stderr dupes to
                                   # whatever stdout now points to (the file)

   Think of ``2>&1`` as "stderr, go wherever stdout is going *right now*."

Modern Shorthand: ``&>`` and ``|&``
--------------------------------------

Bash and Zsh provide convenient shortcuts:

.. code-block:: bash

    $ cmd &> combined.log         # redirect both stdout and stderr (Bash ≥4, Zsh)
    $ cmd &>> combined.log        # append both (Bash ≥4)
    $ cmd |& grep error           # pipe both stdout and stderr (Bash ≥4)
    $ cmd 2>&1 | grep error       # POSIX equivalent

.. note::

   ``&>`` and ``|&`` are **not POSIX**. Use ``> file 2>&1`` in portable
   ``#!/bin/sh`` scripts.

Closing and Moving File Descriptors
-------------------------------------

.. code-block:: bash

    $ cmd 2>&-                     # close stderr (rarely needed)
    $ cmd 3> custom.log            # open FD 3 pointing to file
    $ cmd 3>&2                     # make FD 3 point where FD 2 points
    $ exec 3>&1                    # save current stdout into FD 3
    $ exec 1> output.log           # redirect stdout of the *current shell*
    $ exec 1>&3                    # restore stdout from saved FD 3
    $ exec 3>&-                    # close FD 3

These techniques are used in advanced scripting to temporarily redirect the
shell's own output streams.

.. _pipelines:

Pipelines (``|``)
===================

The pipe (``|``) connects the **stdout** of one command to the **stdin** of
another. It is the quintessential Unix mechanism and the reason the command
line feels like a programmable environment rather than a collection of
isolated tools:

.. code-block:: bash

    $ ls -l /usr/bin | grep '^l' | wc -l
    47

This pipeline: (1) lists ``/usr/bin`` in long format, (2) keeps only symlinks
(lines starting with ``l``), and (3) counts them.

At the kernel level, the shell:

1. Creates a pipe (a kernel buffer with a read end and a write end).
2. Forks ``ls``, connecting its stdout to the pipe's write end.
3. Forks ``grep``, connecting its stdin to the pipe's read end and its stdout
   to *another* pipe.
4. Forks ``wc``, connecting its stdin to the second pipe's read end.
5. All three processes run **concurrently**. ``wc`` reads as ``grep`` writes as
   ``ls`` produces — a streaming, producer-consumer pipeline.

.. important::

   Pipes connect **only stdout**, not stderr. To pipe stderr, you must
   redirect it explicitly:

   .. code-block:: bash

       $ cmd 2>&1 | grep error       # POSIX
       $ cmd |& grep error           # Bash ≥4 shorthand

.. _pipeline-exit-status:

Pipeline Exit Status: ``$PIPESTATUS``
---------------------------------------

``$?`` after a pipeline gives the exit status of the *last* command only:

.. code-block:: bash

    $ false | true
    $ echo $?
    0                    # exit status of 'true', not 'false'

Bash provides ``$PIPESTATUS`` (an array) to inspect all exit codes:

.. code-block:: bash

    $ false | true | false
    $ echo ${PIPESTATUS[@]}
    1 0 1

    $ false | true
    $ echo ${PIPESTATUS[0]}    # exit code of 'false': 1
    $ echo ${PIPESTATUS[1]}    # exit code of 'true': 0

Use ``set -o pipefail`` in scripts to make a pipeline fail if *any* component
fails, not just the last one.

.. _tee:

``tee`` — Duplicate the Stream
================================

``tee`` reads from stdin and writes to **both** stdout and one or more files.
Think of it as a T-junction in a pipeline: data flows through while also being
saved.

.. code-block:: bash

    $ ./configure | tee build.log
    # Output scrolls past AND is saved to build.log

    $ ./configure 2>&1 | tee build.log
    # Capture both stdout and stderr, display AND save

    $ echo "new line" | tee -a log.txt
    # Append mode (-a)

    $ cmd | tee file1 file2 file3
    # Write to multiple files simultaneously

    $ cmd | sudo tee /etc/config.conf > /dev/null
    # Write to a root-owned file from a user shell

.. _process-substitution:

Process Substitution: ``<(cmd)`` and ``>(cmd)``
================================================

Process substitution (Bash, Zsh, but *not* POSIX ``sh``) allows you to treat
the output (or input) of a command as a **file**. The shell spawns the command
and substitutes a special filename (typically ``/dev/fd/N`` or a named pipe):

.. code-block:: bash

    $ diff <(ls dir1) <(ls dir2)
    # Compare the directory listings without temporary files

    $ sort -k2 <(cat file1.txt file2.txt)
    # Merge two files' content through a single sort stdin

    $ tar cf >(gzip -c > archive.tar.gz) dir/
    # Pipe tar's output through gzip without an intermediate file

This is one of the most powerful and underused shell features. It eliminates
the need for temporary files in countless scenarios.

.. _named-pipes:

Named Pipes (FIFOs)
=====================

A *named pipe* is a persistent pipe with a filesystem entry, created with
``mkfifo``. Unlike an anonymous pipe (``|``), a FIFO can connect processes that
did not share a common parent shell:

.. code-block:: bash

    # Terminal 1
    $ mkfifo mypipe
    $ cat mypipe
    # (blocks until something writes to mypipe)

    # Terminal 2
    $ echo "Hello from another terminal" > mypipe

FIFOs are useful for inter-process communication in scripts, but be aware that
opening a FIFO blocks until both a reader and a writer are present. Use
non-blocking I/O or background processes for production use.

.. _here-documents:

Here Documents and Here Strings
=================================

**Here documents** (``<<``) embed multi-line strings directly in shell scripts:

.. code-block:: bash

    $ cat << EOF
    This is line one.
    This is line two.
    Variable: $HOME
    EOF

The delimiter (``EOF``) can be any word. Quoting the delimiter suppresses
variable expansion:

.. code-block:: bash

    $ cat << 'EOF'
    $HOME is not expanded here
    EOF

Use ``<<-`` to strip leading tab characters (useful in indented scripts):

.. code-block:: bash

    if true; then
        cat <<- EOF
        	This line has leading tabs that will be stripped.
        EOF
    fi

**Here strings** (``<<<``) feed a single string as stdin. Bash and Zsh only;
not POSIX:

.. code-block:: bash

    $ grep pattern <<< "search this string"
    $ bc <<< "2 + 2"
    4

.. _noclobber:

Safe Redirection: ``noclobber``
================================

To prevent accidentally overwriting files with ``>``, enable the ``noclobber``
shell option:

.. code-block:: bash

    $ set -o noclobber
    $ echo "data" > existing.txt
    bash: existing.txt: cannot overwrite existing file

    $ echo "data" >| existing.txt    # force overwrite with >|

.. _dev-null:

``/dev/null`` — The Bit Bucket
================================

``/dev/null`` is a special device file that discards all data written to it and
returns EOF (end-of-file) when read. It is indispensible:

.. code-block:: bash

    $ cmd > /dev/null              # discard stdout
    $ cmd 2> /dev/null             # discard stderr
    $ cmd &> /dev/null             # discard both

    $ grep pattern < /dev/null     # always returns nothing (useful for testing)

.. admonition:: Key Takeaway

   Redirection and pipes are not just shell "convenience features" — they are
   the direct expression of Unix's composability philosophy. Mastering them
   means you can assemble complex data-processing workflows from simple,
   single-purpose tools without writing intermediate files or glue code.
   The command line becomes a *dataflow programming environment*.
