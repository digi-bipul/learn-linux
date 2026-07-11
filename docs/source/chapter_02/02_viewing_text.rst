Viewing and Editing Text
========================

The Unix philosophy holds that the configuration of a system — its users,
services, network settings, and startup scripts — should be stored in plain
text files.  A Linux administrator therefore spends a great deal of time
simply *looking* at files.  This section introduces the essential tools for
peering into files, from the quick glance to the deep interactive read, and
concludes with a brief introduction to terminal‑based text editors.

.. contents:: :local:
   :depth: 2


The Unix Philosophy and Plain Text
----------------------------------

Why plain text?  Binary formats are opaque: you need a special program to
read them, and when that program breaks or becomes unavailable, your data is
inaccessible.  Plain text is transparent, portable, and tool‑friendly.  Every
tool in this chapter — ``cat``, ``less``, ``head``, ``tail`` — reads and
writes plain text, and you can chain them together with pipes (a topic we
will explore in depth in a later chapter).


Concatenating Files with ``cat``
--------------------------------

The ``cat`` (concatenate) command reads one or more files sequentially and
prints their contents to standard output.  Its name reflects its original
purpose — to concatenate files — but it is most often used simply to display
a short file:

.. code-block:: bash

   cat /etc/hostname

``cat`` really shines with its formatting options:

``-n``, ``--number``
   Number all output lines, starting from 1:

   .. code-block:: bash

      $ cat -n /etc/hostname
           1  mymachine

``-b``, ``--number-nonblank``
   Number only non‑empty lines.  Useful for source code where blank lines
   are intentional spacing.

``-s``, ``--squeeze-blank``
   Suppress repeated empty output lines.  If a file has three consecutive
   blank lines, ``-s`` reduces them to one.  Excellent for tidying log
   output.

``-A``, ``--show-all``
   Equivalent to ``-vET`` — reveals normally invisible characters:

   * ``-v``: Show non‑printing characters (except tabs and line feeds) using
     caret notation (e.g., ``^M`` for carriage return).
   * ``-E``: Display a ``$`` at the end of each line.
   * ``-T``: Display tab characters as ``^I``.

   This is invaluable for debugging files with Windows‑style line endings
   (``\r\n``), trailing spaces, or mixed tabs and spaces:

   .. code-block:: bash

      $ cat -A windows_file.txt
      Hello, World!^M$
      Line two^M$

``-t``
   Equivalent to ``-vT`` (show non‑printing characters and tabs).

.. note::

   There is also a command called ``tac`` (``cat`` reversed) that prints
   files in reverse line order — last line first.  While not an everyday
   tool, it is occasionally useful for processing logs where the newest
   entries are at the bottom.

``cat`` is not suitable for large files because it dumps the entire content
to the terminal in one go.  For files longer than your screen, reach for
``less``.


Interactive Paging with ``less``
---------------------------------

``less`` is a *pager* — a program that displays text one screen at a time and
lets you navigate interactively.  Despite its name (a pun on the older
``more`` pager, because "less is more"), ``less`` is far more capable than
``more`` and has largely replaced it.

.. code-block:: bash

   less /var/log/syslog

Once inside ``less``, you control navigation with keyboard commands:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Key
     - Action
   * - :kbd:`Space` or :kbd:`f`
     - Forward one screen
   * - :kbd:`b`
     - Backward one screen
   * - :kbd:`j` or :kbd:`Down`
     - Forward one line
   * - :kbd:`k` or :kbd:`Up`
     - Backward one line
   * - :kbd:`g`
     - Go to the first line
   * - :kbd:`G`
     - Go to the last line
   * - :kbd:`/pattern`
     - Search forward for *pattern*
   * - :kbd:`?pattern`
     - Search backward for *pattern*
   * - :kbd:`n`
     - Repeat last search forward
   * - :kbd:`N`
     - Repeat last search backward
   * - :kbd:`q`
     - Quit
   * - :kbd:`h`
     - Display help

``less`` can do far more than this table suggests — it supports regular
expression searches, horizontal scrolling, multiple file browsing, and even
piping to shell commands from within the viewer (``!command``).  Run ``less
--help`` or press :kbd:`h` inside ``less`` for the full list.

Important command‑line options:

``-N``
   Display line numbers in the left margin.

``-S``, ``--chop-long-lines``
   Truncate lines that are wider than the terminal instead of wrapping them.
   Use the left and right arrow keys to scroll horizontally.  This is
   especially useful for viewing CSV files or wide log lines.

``-R``, ``--RAW-CONTROL-CHARS``
   Pass ANSI colour escape sequences through to the terminal.  If a command
   produces coloured output (e.g., ``grep --color``), pipe it through
   ``less -R`` to preserve the colours:

   .. code-block:: bash

      grep --color error /var/log/syslog | less -R

``-F``, ``--quit-if-one-screen``
   If the entire file fits on one screen, ``less`` exits immediately
   (behaving like ``cat``).  This is often set in the ``$LESS`` environment
   variable for convenience:

   .. code-block:: bash

      export LESS='-FRX'

   Here ``-X`` prevents ``less`` from clearing the screen on exit, so the
   output remains visible after ``less`` quits.

``+F``
   Start in "follow" mode, similar to ``tail -f`` (see below).  Press
   :kbd:`Ctrl-c` to stop following and return to normal navigation.

``+*number*``
   Jump to line *number* on startup:

   .. code-block:: bash

      less +100 file.txt    # Start at line 100


The Elder: ``more``
~~~~~~~~~~~~~~~~~~~

You may occasionally encounter ``more`` on very minimal systems (embedded
Linux, rescue shells).  It is a simpler pager: forward navigation only, no
backward scrolling, and a limited feature set.  Whenever possible, use
``less`` instead.  If you accidentally find yourself in ``more``, press
:kbd:`q` to quit.


Viewing File Starts with ``head``
----------------------------------

``head`` prints the first lines of a file — by default, the first 10:

.. code-block:: bash

   head /etc/passwd

Options:

``-n *N*``, ``--lines=*N*``
   Print the first *N* lines.  Negative *N* prints all *except* the last *N*
   lines:

   .. code-block:: bash

      head -n 3 file.txt     # First 3 lines
      head -n -3 file.txt    # All except the last 3 lines

``-c *N*``, ``--bytes=*N*``
   Print the first *N* bytes instead of lines.  *N* can include a multiplier
   suffix: ``b`` (512), ``KB`` (1000), ``K`` (1024), ``MB``, ``M``, etc.

   .. code-block:: bash

      head -c 1K largefile   # First 1024 bytes

``-q``, ``--quiet``, ``--silent``
   Never print the file name header when processing multiple files.

``-v``, ``--verbose``
   Always print the file name header.


Viewing File Ends and Following with ``tail``
-----------------------------------------------

``tail`` is the complement of ``head``: it prints the last 10 lines of a
file.  It is indispensable for monitoring log files in real time.

.. code-block:: bash

   tail /var/log/syslog

Options:

``-n *N*``, ``--lines=*N*``
   Print the last *N* lines.  With a ``+`` prefix, print starting from line
   *N*:

   .. code-block:: bash

      tail -n 5 file.txt     # Last 5 lines
      tail -n +5 file.txt    # All lines starting from line 5

``-c *N*``, ``--bytes=*N*``
   Print the last *N* bytes.

``-f``, ``--follow``
   **Follow mode.**  After printing the last lines, ``tail`` keeps the file
   open and prints new lines as they are appended.  This is the classic
   command for watching a log file in real time:

   .. code-block:: bash

      tail -f /var/log/nginx/access.log

   Press :kbd:`Ctrl-c` to stop following.

``-F``
   Like ``-f``, but if the file is rotated (renamed and replaced by a log
   rotation tool), ``tail`` detects the change and re‑opens the new file.
   Always prefer ``-F`` over ``-f`` for long‑running log monitoring.

``-q`` / ``-v``
   Suppress / always show file name headers, as with ``head``.

A common pattern is to combine ``tail -F`` with ``grep`` to watch for
specific events:

.. code-block:: bash

   tail -F /var/log/syslog | grep --line-buffered ERROR


Introduction to Text Editors
-----------------------------

Viewing text is only half the story; you also need to *edit* configuration
files, scripts, and notes.  Linux offers two major terminal‑based editors
that every administrator should know at least at a basic level.

nano: The Beginner‑Friendly Editor
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``nano`` is a straightforward, modeless editor.  You open a file, type,
use arrow keys to navigate, and follow the on‑screen shortcuts at the bottom
of the terminal:

.. code-block:: bash

   nano myfile.txt

The two‑line "help bar" at the bottom shows common commands using caret
notation (``^`` means :kbd:`Ctrl`):

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Keystroke
     - Action
   * - :kbd:`Ctrl-o`
     - Write ("save") the file
   * - :kbd:`Ctrl-x`
     - Exit nano
   * - :kbd:`Ctrl-k`
     - Cut current line
   * - :kbd:`Ctrl-u`
     - Paste ("uncut")
   * - :kbd:`Ctrl-w`
     - Search
   * - ``Ctrl-\``
     - Search and replace
   * - :kbd:`Ctrl-g`
     - Show full help

``nano`` is ideal for quick edits when you do not want to think about editor
modes.  If a system asks you to "edit a file" and you are unsure which editor
to use, ``nano`` is the safest default.

.. note::

   On some minimal distributions (Alpine Linux, Docker containers),
   ``nano`` may not be installed.  In those environments, ``vi`` (or
   ``vim``) is almost always available.

vim: The Power User's Editor (Crash Course)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``vim`` (Vi IMproved) is a modal editor derived from the original ``vi``.
It is immensely powerful, but its modal design — where the same key does
different things in different modes — presents a steep initial learning
curve.  This is the absolute minimum you need to know to survive.

Open a file:

.. code-block:: bash

   vim myfile.txt

**Vim starts in Normal mode.**  You cannot type text immediately.  The first
thing to learn is how to enter Insert mode and how to get back:

* Press :kbd:`i` to enter **Insert mode**.  Now you can type normally.
* Press :kbd:`Esc` to return to **Normal mode**.

Once back in Normal mode, these commands are essential:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Keystroke
     - Action
   * - ``:w``
     - Write (save) the file
   * - ``:q``
     - Quit
   * - ``:wq`` or ``ZZ``
     - Write and quit
   * - ``:q!``
     - Quit **without saving** (discard changes)
   * - ``dd``
     - Delete the current line
   * - ``u``
     - Undo
   * - ``/pattern``
     - Search forward for *pattern*
   * - ``:set number``
     - Show line numbers
   * - ``:set nonumber``
     - Hide line numbers
   * - ``:help``
     - Open vim's excellent built‑in help

.. warning::

   If you ever find yourself stuck in vim, remember:

   1. Press :kbd:`Esc` a couple of times (to ensure you are in Normal mode).
   2. Type ``:q!`` and press :kbd:`Enter` to quit without saving.

   This sequence will get you out of virtually any situation.

A full treatment of ``vim`` is beyond the scope of this book — entire volumes
have been written about it.  For now, the commands above are enough to edit a
configuration file and escape with your changes (or your sanity) intact.  We
will return to ``vim`` in greater depth in a later chapter on advanced text
editing.

.. tip::

   To change your default editor system‑wide, use the ``update-alternatives``
   mechanism (Debian/Ubuntu) or set the ``$EDITOR`` and ``$VISUAL``
   environment variables in your shell configuration file:

   .. code-block:: bash

      export EDITOR=nano
      export VISUAL=nano


Practical Exercises
-------------------

#. Use ``cat -n`` on ``/etc/hosts``.  Then use ``cat -A`` on the same file.
   What invisible characters, if any, are revealed?

#. Open ``/var/log/syslog`` (or ``/var/log/messages`` on RHEL‑based systems)
   with ``less``.  Practice:

   * Searching for the word "error" with ``/error``.
   * Jumping to the end with :kbd:`G` and back to the start with :kbd:`g`.
   * Viewing line numbers with ``-N`` (quit and restart with ``less -N``).

#. Display the first 5 lines of ``/etc/passwd`` and the last 3 lines of the
   same file using ``head`` and ``tail``.

#. Start ``tail -F`` on ``/var/log/syslog`` (you may need ``sudo``) in one
   terminal.  In a second terminal, run ``logger "Test message from Chapter
   2"``.  Observe the message appear in your ``tail`` window.  Press
   :kbd:`Ctrl-c` to stop.

#. Create a file called ``practise.txt`` with ``nano``.  Write a few lines
   of text, save it with :kbd:`Ctrl-o`, and exit with :kbd:`Ctrl-x`.

#. Open the same file with ``vim``.  Practise entering Insert mode with
   :kbd:`i`, adding a line, pressing :kbd:`Esc`, and saving with ``:wq``.
   Then reopen it and practise quitting without saving with ``:q!``.
