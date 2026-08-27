#!/usr/bin/env python3
"""Validate the lightweight CGeV manuscript reviewer package."""

from __future__ import annotations

import csv
import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "examples" / "manuscript-cases"
QUERIES = PACKAGE / "inputs" / "queries.tsv"
EXPECTED = PACKAGE / "expected" / "resolved_genes.tsv"
REGISTRY = ROOT / "annotations" / "registry.tsv"
CHECKSUMS = PACKAGE / "checksums.sha256"


def fail(message: str) -> None:
    raise ValueError(message)


def read_tsv(
    path: Path, fields: list[str], *, allow_empty: bool = False
) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames != fields:
            fail(f"{path.relative_to(ROOT)} has unexpected columns: {reader.fieldnames}")
        rows = list(reader)
    if not rows:
        fail(f"{path.relative_to(ROOT)} is empty")
    if not allow_empty and any(not value.strip() for row in rows for value in row.values()):
        fail(f"{path.relative_to(ROOT)} contains an empty field")
    return rows


def validate_checksums() -> None:
    declared: dict[str, str] = {}
    for line in CHECKSUMS.read_text(encoding="ascii").splitlines():
        digest, relative = line.split("  ", 1)
        declared[relative] = digest
    required = [
        "inputs/queries.tsv",
        "expected/resolved_genes.tsv",
        "expected/acceptance_criteria.md",
    ]
    if sorted(declared) != sorted(required):
        fail("checksums.sha256 does not list exactly the reviewer inputs and expectations")
    for relative in required:
        actual = hashlib.sha256((PACKAGE / relative).read_bytes()).hexdigest()
        if actual != declared[relative]:
            fail(f"checksum mismatch for {relative}")


def main() -> int:
    query_fields = [
        "case_id", "workflow", "query_order", "organism", "species_id",
        "assembly_accession", "query",
    ]
    expected_fields = [
        "case_id", "query_order", "species_id", "input_query",
        "resolved_symbol", "figure_label", "resolution_status",
    ]
    queries = read_tsv(QUERIES, query_fields)
    expected = read_tsv(EXPECTED, expected_fields)
    registry = read_tsv(
        REGISTRY,
        [
            "species_id", "label", "organism", "taxid", "annotation",
            "annotation_tabix", "annotation_index", "genome", "genome_2bit",
            "aliases", "icon", "kingdom",
        ],
        allow_empty=True,
    )

    registry_by_id = {row["species_id"]: row for row in registry}
    if len(registry_by_id) != len(registry):
        fail("annotations/registry.tsv contains duplicate species_id values")

    query_keys: set[tuple[str, str]] = set()
    for row in queries:
        key = (row["case_id"], row["query_order"])
        if key in query_keys:
            fail(f"duplicate query key: {key}")
        query_keys.add(key)
        registered = registry_by_id.get(row["species_id"])
        if registered is None:
            fail(f"unknown species_id in queries.tsv: {row['species_id']}")
        if registered["organism"] != row["organism"]:
            fail(f"organism mismatch for {row['species_id']}")
        registry_paths = registered["annotation"] + " " + registered["genome_2bit"]
        if row["assembly_accession"] not in registry_paths:
            fail(f"assembly accession mismatch for {row['species_id']}")

    expected_keys: set[tuple[str, str]] = set()
    queries_by_key = {(row["case_id"], row["query_order"]): row for row in queries}
    for row in expected:
        key = (row["case_id"], row["query_order"])
        if key in expected_keys:
            fail(f"duplicate expected-output key: {key}")
        expected_keys.add(key)
        query = queries_by_key.get(key)
        if query is None:
            fail(f"expected output has no matching input: {key}")
        if row["species_id"] != query["species_id"] or row["input_query"] != query["query"]:
            fail(f"expected output does not match its input: {key}")
        if row["resolution_status"] not in {"resolved", "resolved_alias"}:
            fail(f"unsupported resolution status: {row['resolution_status']}")

    if query_keys != expected_keys:
        fail("input and expected-output keys differ")
    counts = {
        case: sum(row["case_id"] == case for row in queries)
        for case in {row["case_id"] for row in queries}
    }
    if counts != {"hkt_rice": 7, "tp53_cross_species": 7}:
        fail(f"unexpected case composition: {counts}")

    validate_checksums()
    print(
        "PASS: reviewer package is internally consistent "
        f"({len(counts)} cases, {len(queries)} queries, {len(registry)} registered datasets)."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, UnicodeError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
