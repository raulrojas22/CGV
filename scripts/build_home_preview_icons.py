#!/usr/bin/env python3
"""Build the small, home-only PNG icon variants used by the static landing page."""

from __future__ import annotations

import argparse
import io
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = REPO_ROOT / "www" / "icons" / "home"


@dataclass(frozen=True)
class HomeIcon:
    output_name: str
    source_path: str
    max_size: tuple[int, int]


HOME_ICONS = (
    HomeIcon("favicon-light@2x.png", "www/favicon2.ico", (62, 62)),
    HomeIcon("favicon-dark@2x.png", "www/favicon.ico", (62, 62)),
    HomeIcon("database-mygene@2x.png", "www/icons/databases/mygene.ico", (28, 28)),
    HomeIcon("database-ncbi@2x.png", "www/icons/databases/ncbi.ico", (28, 28)),
    HomeIcon("database-uniprot@2x.png", "www/icons/databases/uniprot.ico", (28, 28)),
    HomeIcon("database-ensembl@2x.png", "www/icons/databases/ensembl.ico", (28, 28)),
    HomeIcon("species-homo-sapiens@2x.png", "www/icons/Homo sapiens.ico", (48, 48)),
    HomeIcon("species-mus-musculus@2x.png", "www/icons/Mus musculus.ico", (48, 48)),
    HomeIcon("species-danio-rerio@2x.png", "www/icons/Danio rerio.ico", (48, 48)),
    HomeIcon(
        "species-arabidopsis-thaliana@2x.png",
        "www/icons/Arabidopsis thaliana.ico",
        (48, 48),
    ),
    HomeIcon(
        "species-oryza-sativa-japonica@2x.png",
        "www/icons/Oryza sativa japonica.ico",
        (48, 48),
    ),
    HomeIcon(
        "species-saccharomyces-cerevisiae@2x.png",
        "www/icons/Saccharomyces cerevisiae.ico",
        (48, 48),
    ),
)


def render_icon(spec: HomeIcon) -> Image.Image:
    source = REPO_ROOT / spec.source_path
    if not source.is_file():
        raise FileNotFoundError(f"missing canonical icon: {source}")

    with Image.open(source) as image:
        rendered = image.convert("RGBA")
        rendered.thumbnail(
            spec.max_size,
            Image.Resampling.LANCZOS,
            reducing_gap=3.0,
        )
        return rendered.copy()


def encode_png(image: Image.Image) -> bytes:
    payload = io.BytesIO()
    image.save(payload, format="PNG", compress_level=9, optimize=False)
    return payload.getvalue()


def write_icons() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for spec in HOME_ICONS:
        target = OUTPUT_DIR / spec.output_name
        target.write_bytes(encode_png(render_icon(spec)))
        print(f"wrote {target.relative_to(REPO_ROOT)} ({target.stat().st_size} bytes)")


def check_icons() -> None:
    for spec in HOME_ICONS:
        target = OUTPUT_DIR / spec.output_name
        if not target.is_file():
            raise AssertionError(f"missing generated home icon: {target}")

        expected = render_icon(spec)
        expected_bytes = encode_png(expected)
        if target.read_bytes() != expected_bytes:
            raise AssertionError(f"bytes differ from deterministic PNG build: {target}")

        with Image.open(target) as actual_image:
            actual_image.load()
            actual = actual_image.convert("RGBA")
            if actual_image.format != "PNG":
                raise AssertionError(f"expected PNG output: {target}")
            if actual.size != expected.size:
                raise AssertionError(
                    f"unexpected dimensions for {target}: {actual.size} != {expected.size}"
                )
            if actual.tobytes() != expected.tobytes():
                raise AssertionError(
                    f"pixels differ from deterministic canonical resize: {target}"
                )

    print(
        "home-preview-icon-build-ok "
        f"({len(HOME_ICONS)} deterministic PNG assets; bytes and pixels verified)"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="write the generated PNG assets")
    mode.add_argument("--check", action="store_true", help="verify committed PNG bytes and pixels")
    args = parser.parse_args()

    if args.write:
        write_icons()
    else:
        check_icons()


if __name__ == "__main__":
    main()
