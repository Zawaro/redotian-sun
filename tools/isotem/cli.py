"""Command-line entry point for the .tem parser.

Usage:
    python tools/isotem/cli.py <file.tem> ...
    python tools/isotem/cli.py --check
"""

from tem import main

if __name__ == "__main__":
    raise SystemExit(main())
