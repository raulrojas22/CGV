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
REPORT_ALIAS_RE = re.compile(
    r"(?m)^[ \t]*alias[ \t]+/srv/cgv-cache/shared_reports/\$1/index[.]html;"
    r"[ \t]*(?:#.*)?$"
)
REPORT_CSP_ANCHOR_RE = re.compile(
    r"(?m)^[ \t]*add_header[ \t]+Content-Security-Policy(?=[ \t])"
)
REPORT_CSP_HEADER_RE = re.compile(
    r'^[ \t]*add_header[ \t]+Content-Security-Policy[ \t]+'
    r'"(?P<policy>(?:\\.|[^"\\])*)"[ \t]+always[ \t]*;[ \t]*(?:#.*)?$'
)


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


def _structural_brace_pairs(config: str) -> list[tuple[int, int]]:
    """Return nginx block pairs while ignoring quoted regexes and comments."""
    stack: list[int] = []
    pairs: list[tuple[int, int]] = []
    quote = ""
    escaped = False
    comment = False

    for index, character in enumerate(config):
        if comment:
            if character in "\r\n":
                comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character == "#":
            comment = True
        elif character in "'\"":
            quote = character
        elif character == "{":
            stack.append(index)
        elif character == "}":
            if not stack:
                raise ValueError("malformed nginx config: unmatched closing brace")
            pairs.append((stack.pop(), index))

    if quote:
        raise ValueError("malformed nginx config: unterminated quoted string")
    if stack:
        raise ValueError("malformed nginx config: unmatched opening brace")
    return pairs


def _unique_report_location(config: str) -> tuple[int, int]:
    aliases = list(REPORT_ALIAS_RE.finditer(config))
    if len(aliases) != 1:
        raise ValueError("expected exactly one shared-report index alias")

    alias_position = aliases[0].start()
    containing = [
        pair
        for pair in _structural_brace_pairs(config)
        if pair[0] < alias_position < pair[1]
    ]
    if not containing:
        raise ValueError("shared-report index alias is not inside an nginx block")
    location = min(containing, key=lambda pair: pair[1] - pair[0])
    opening_line = config[config.rfind("\n", 0, location[0]) + 1 : location[0]].strip()
    if re.match(r"^location(?:[ \t]|$)", opening_line) is None:
        raise ValueError("shared-report index alias is not directly inside a location block")
    return location


def _script_src_span(policy: str) -> tuple[int, int, list[str]]:
    directives: list[tuple[int, int, str, str]] = []
    start = 0
    for end in [match.start() for match in re.finditer(";", policy)] + [len(policy)]:
        segment = policy[start:end]
        match = re.fullmatch(
            r"(?P<leading>[ \t]*)(?P<name>[A-Za-z][A-Za-z0-9-]*)"
            r"(?P<sources>(?:[ \t]+[^;]*?)?)(?P<trailing>[ \t]*)",
            segment,
        )
        if match is None:
            raise ValueError("malformed Content-Security-Policy directive")
        directives.append((
            start + match.start("sources"),
            start + match.end("sources"),
            match.group("name"),
            match.group("sources"),
        ))
        start = end + 1

    script_sources = [directive for directive in directives if directive[2] == "script-src"]
    if len(script_sources) != 1:
        raise ValueError("expected exactly one script-src in the shared-report CSP")
    source_start, source_end, _name, source_text = script_sources[0]
    tokens = source_text.split()
    if not tokens:
        raise ValueError("shared-report script-src must contain at least one sha256 hash")
    hashes: list[str] = []
    for token in tokens:
        if len(token) < 2 or token[0] != "'" or token[-1] != "'":
            raise ValueError("shared-report script-src may contain only quoted sha256 hashes")
        value = token[1:-1]
        if REPORT_SCRIPT_HASH_RE.fullmatch(value) is None:
            raise ValueError("shared-report script-src may contain only quoted sha256 hashes")
        hashes.append(value)
    if len(set(hashes)) != len(hashes):
        raise ValueError("shared-report script-src contains duplicate sha256 hashes")
    return source_start, source_end, hashes


def update_report_script_hash(config: str, expected_hash: str) -> str:
    if REPORT_SCRIPT_HASH_RE.fullmatch(expected_hash) is None:
        raise ValueError("report script hash must be one complete sha256 CSP token")
    location_start, location_end = _unique_report_location(config)
    location_body_start = location_start + 1
    location_body = config[location_body_start:location_end]
    csp_anchors = list(REPORT_CSP_ANCHOR_RE.finditer(location_body))
    if len(csp_anchors) != 1:
        raise ValueError("expected exactly one CSP header in the shared-report location")

    header_start = csp_anchors[0].start()
    header_end = location_body.find("\n", header_start)
    if header_end == -1:
        header_end = len(location_body)
    header = location_body[header_start:header_end]
    header_match = REPORT_CSP_HEADER_RE.fullmatch(header)
    if header_match is None:
        raise ValueError("shared-report CSP header must be one complete quoted line with always")
    absolute_header_start = location_body_start + header_start
    header_blocks = [
        pair
        for pair in _structural_brace_pairs(config)
        if pair[0] < absolute_header_start < pair[1]
    ]
    if not header_blocks or min(header_blocks, key=lambda pair: pair[1] - pair[0]) != (
        location_start,
        location_end,
    ):
        raise ValueError("shared-report CSP header is not directly inside its location block")

    policy = header_match.group("policy")
    source_start, source_end, hashes = _script_src_span(policy)
    if expected_hash in hashes:
        return config

    policy_start = (
        location_body_start
        + header_start
        + header_match.start("policy")
    )
    source_text = policy[source_start:source_end]
    insertion = policy_start + source_start + len(source_text.rstrip(" \t"))
    return config[:insertion] + f" '{expected_hash}'" + config[insertion:]


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
