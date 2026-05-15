"""Make the repo root importable so tests can do `from python.edit_checks ...`."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
