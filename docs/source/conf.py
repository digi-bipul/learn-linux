# ── Path setup ──────────────────────────────────────────
import os
import sys
sys.path.insert(0, os.path.abspath("."))

# ── Project info ────────────────────────────────────────
project   = "Learn Linux Docs"
copyright = "2026, Bipul"
author    = "Bipul Das"
release   = "0.1.0"

# ── Theme ───────────────────────────────────────────────
html_theme = "sphinx_rtd_theme"

# ── Custom CSS ──────────────────────────────────────────
html_static_path = ["_static"]
html_css_files   = ["custom.css"]

# ── Extensions (start lean, add as needed) ──────────────
extensions = [
    "sphinx.ext.autodoc",    # pull docstrings from Python code (safe to keep)
    "sphinx.ext.viewcode",   # add [source] links (optional but nice)
]
