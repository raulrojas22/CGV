#!/usr/bin/env python3
"""Verify immutable CGV assets through the deployed nginx HTTP path."""

from __future__ import annotations

import argparse
import http.client
import re
from urllib.parse import urlsplit


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()

    if re.fullmatch(r"[a-f0-9]{64}", args.revision) is None:
        raise ValueError("revision must be a 64-character lowercase sha256 Id")
    parsed = urlsplit(args.base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("base-url must be an absolute HTTP(S) URL")
    connection_type = (
        http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    )
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    prefix = parsed.path.rstrip("/")

    def request(method: str, path: str, headers: dict[str, str] | None = None):
        connection = connection_type(parsed.hostname, port, timeout=15)
        connection.request(method, prefix + path, headers=headers or {})
        response = connection.getresponse()
        body = response.read()
        result = (response.status, {k.lower(): v for k, v in response.getheaders()}, body)
        connection.close()
        return result

    asset_path = f"/cgv-static/{args.revision}/js/version_probe.js"
    status, headers, body = request("GET", asset_path)
    assert status == 200, ("GET status", status)
    assert body, "GET body is empty"
    cache_control = headers.get("cache-control", "")
    assert "max-age=31536000" in cache_control and "immutable" in cache_control
    assert headers.get("etag"), "ETag is missing"
    assert headers.get("accept-ranges", "").lower() == "bytes"

    head_status, head_headers, head_body = request("HEAD", asset_path)
    assert head_status == 200 and not head_body
    assert head_headers.get("etag") == headers["etag"]

    conditional_status, _, conditional_body = request(
        "GET", asset_path, {"If-None-Match": headers["etag"]}
    )
    assert conditional_status == 304 and not conditional_body

    video_path = f"/cgv-static/{args.revision}/screencasts/guide-intro.mp4"
    range_status, range_headers, range_body = request(
        "GET", video_path, {"Range": "bytes=0-1023"}
    )
    assert range_status == 206, ("Range status", range_status)
    assert len(range_body) == 1024, ("Range length", len(range_body))
    assert re.fullmatch(r"bytes 0-1023/[1-9][0-9]*", range_headers.get("content-range", ""))

    missing_status, _, _ = request(
        "GET", "/cgv-static/not-a-release/js/version_probe.js"
    )
    assert missing_status == 404, ("invalid release status", missing_status)
    method_status, _, _ = request("POST", asset_path)
    assert method_status in {403, 405}, ("POST status", method_status)

    print(f"static-asset-http-ok revision={args.revision}")


if __name__ == "__main__":
    main()
