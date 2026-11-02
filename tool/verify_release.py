"""Fail closed unless an owner-published release matches a commit on stable main."""
import os
import re
import subprocess
from pathlib import Path

tag = os.environ.get("RELEASE_TAG", "")
if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
    raise SystemExit("Expected a semantic release tag such as v0.1.0")
version = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", Path("pubspec.yaml").read_text(), re.M)
if not version or tag != "v" + version.group(1):
    raise SystemExit("Release tag does not match pubspec.yaml")
subprocess.run(["git", "merge-base", "--is-ancestor", "HEAD", "origin/main"], check=True)
