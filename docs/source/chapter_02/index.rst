==================================================
Chapter 2: The Shell & Command Line
==================================================

The shell is the gateway to Linux. It is simultaneously the humblest and most
powerful interface you will ever wield — a deceptively simple text prompt that,
in skilled hands, orchestrates everything from one-off file renames to
planet-scale infrastructure automation. If Chapter 1 gave you the map of the
Linux landscape, this chapter teaches you to drive.

We begin by dismantling the shell itself to see how it *thinks*: how it finds
commands, distinguishes builtins from external binaries, and parses the lines
you type (Section 2.1). From there we explore the Unix philosophy of
composability through I/O redirection and pipelines — the "small pieces,
loosely joined" principle that makes the command line a programmable
environment rather than a mere command launcher (Section 2.2).

With the mechanics understood, we turn to customisation: environment variables,
startup files, and the art of shaping the shell into *your* shell (Section 2.3).
Then we arm you with the text-processing toolkit that turns unstructured log
files into actionable data (Section 2.4), and its two heavyweight champions,
``sed`` and ``awk`` (Section 2.5).

Finally, we address the human factors: how to never type the same command twice
(Section 2.6) and how to keep programs running when you walk away from the
terminal (Section 2.7).

By the end of this chapter, the terminal will feel less like a foreign console
and more like a workshop where every tool is within arm's reach.

.. toctree::
   :maxdepth: 2

   01_shell_architecture
   02_io_redirection
   03_environment_and_config
   04_text_processing
   05_sed_and_awk
   06_history_efficiency
   07_job_control
