#!/usr/bin/env python3
"""Build an idempotent nginx candidate with the canonical CGV static block."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import tempfile


BEGIN = "    # BEGIN CGV IMMUTABLE STATIC v1"
END = "    # END CGV IMMUTABLE STATIC v1"
ANCHOR = "    location / {\n"
REPORT_SCRIPT_HASH_RE = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")


def normalized_snippet(path: Path) -> str:
    snippet = path.read_text(encoding="utf-8")
    if not snippet.endswith("\n"):
        snippet += "\n"
    if snippet.count(BEGIN) != 1 or snippet.count(END) != 1:
        raise ValueError("the canonical snippet must contain one complete marker pair")
    if snippet.index(BEGIN) >= snippet.index(END):
        raise ValueError("the canonical snippet markers are out of order")
    return snippet


def build_candidate(config: str, snippet: str) -> str:
    begin_count = config.count(BEGIN)
    end_count = config.count(END)
    if (begin_count, end_count) == (0, 0):
        if config.count(ANCHOR) != 1:
            raise ValueError("expected exactly one generic 'location / {' anchor")
        return config.replace(ANCHOR, snippet + "\n" + ANCHOR, 1)
    if (begin_count, end_count) != (1, 1):
        raise ValueError("malformed or duplicate CGV static marker block")

    start = config.index(BEGIN)
    end = config.index(END, start) + len(END)
    if end < len(config) and config[end] == "\n":
        end += 1
    if config[start:end] != snippet:
        raise ValueError("existing CGV static block differs from the canonical snippet")
    return config


def update_report_script_hash(config: str, expected_hash: str) -> str:
    if REPORT_SCRIPT_HASH_RE.fullmatch(expected_hash) is None:
        raise ValueError("report script hash must be one complete sha256 CSP token")
    matches = REPORT_SCRIPT_HASH_RE.findall(config)
    if len(matches) != 1:
        raise ValueError("expected exactly one shared-report sha256 CSP token")
    return REPORT_SCRIPT_HASH_RE.sub(expected_hash, config, count=1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--snippet", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report-script-hash", default="")
    args = parser.parse_args()

    if args.config.resolve() == args.output.resolve():
        raise ValueError("output must be a separate candidate path")
    if args.config.is_symlink() or args.output.is_symlink():
        raise ValueError("config and candidate paths must not be symlinks")

    config = args.config.read_text(encoding="utf-8")
    candidate = build_candidate(config, normalized_snippet(args.snippet))
    if args.report_script_hash:
        candidate = update_report_script_hash(candidate, args.report_script_hash)
    config_stat = args.config.stat()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(
        prefix=f".{args.output.name}.", dir=str(args.output.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(candidate)
            handle.flush()
            os.fsync(handle.fileno())
        shutil.copystat(args.config, temp_name, follow_symlinks=False)
        try:
            os.chown(temp_name, config_stat.st_uid, config_stat.st_gid)
        except PermissionError as error:
            raise PermissionError(
                "cannot preserve the server-owned nginx uid/gid on the candidate"
            ) from error
        metadata_fd = os.open(temp_name, os.O_RDONLY)
        try:
            os.fsync(metadata_fd)
        finally:
            os.close(metadata_fd)
        os.replace(temp_name, args.output)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
