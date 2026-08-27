#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER_PATH = ROOT / "scripts" / "build_nginx_static_candidate.py"
SPEC = importlib.util.spec_from_file_location("cgv_nginx_candidate", HELPER_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SNIPPET_PATH = ROOT / "deploy" / "nginx" / "cgv-static-assets.location.conf"
NGINX_PATH = ROOT / "deploy" / "nginx" / "cgv-shinyproxy.conf"
snippet = MODULE.normalized_snippet(SNIPPET_PATH)

base = "server {\n    listen 8080;\n\n    location / {\n        return 204;\n    }\n}\n"
inserted = MODULE.build_candidate(base, snippet)
assert inserted.count(MODULE.BEGIN) == 1
assert inserted.count(MODULE.END) == 1
assert MODULE.build_candidate(inserted, snippet) == inserted

drifted = inserted.replace("etag on;", "etag off;")
try:
    MODULE.build_candidate(drifted, snippet)
except ValueError as error:
    assert "differs" in str(error)
else:
    raise AssertionError("a drifted managed block was accepted")

try:
    MODULE.build_candidate(inserted + snippet, snippet)
except ValueError as error:
    assert "duplicate" in str(error)
else:
    raise AssertionError("duplicate marker blocks were accepted")

tracked_nginx = NGINX_PATH.read_text(encoding="utf-8")
assert MODULE.build_candidate(tracked_nginx, snippet) == tracked_nginx
oldest_hash = "sha256-hzu6tHcnWHA4k15V7TSOwQ9voERkwOk5iJWRIHKmwTE="
old_hash = "sha256-VJ57di/IQ0e4GQS4gxb2N0MxDIJ1cTW0ycxWaMfXqog="
expected_hash = "sha256-EXkIJnQvs/u+7Sw8WFMz21f46Zk6qxolUQbZIaQ9yfg="
foreign_hash = "sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="
report_script_src = f"script-src '{oldest_hash}' '{old_hash}'"
report_csp_header = (
    "        add_header Content-Security-Policy \"default-src 'none'; "
    f"{report_script_src}; connect-src 'none'\" always;\n"
)
report_config = (
    "server {\n"
    "    listen 8080;\n"
    "\n"
    "    location = /unrelated {\n"
    "        add_header Content-Security-Policy \"default-src 'none'; "
    f"script-src '{foreign_hash}'\" always;\n"
    "    }\n"
    "\n"
    '    location ~ "^/share/([a-f0-9]{64})(?:/index[.]html|/?)$" {\n'
    "        alias /srv/cgv-cache/shared_reports/$1/index.html;\n"
    f"{report_csp_header}"
    "    }\n"
    "\n"
    "    location / {\n"
    "        return 204;\n"
    "    }\n"
    "}\n"
)
updated_csp = MODULE.update_report_script_hash(report_config, expected_hash)
expected_csp = report_config.replace(
    report_script_src,
    f"{report_script_src} '{expected_hash}'",
    1,
)
assert updated_csp == expected_csp
assert oldest_hash in updated_csp and old_hash in updated_csp
assert updated_csp.count(expected_hash) == 1
assert f"script-src '{foreign_hash}'" in updated_csp
assert MODULE.update_report_script_hash(updated_csp, expected_hash) == updated_csp
assert MODULE.update_report_script_hash(tracked_nginx, expected_hash) == tracked_nginx


def rejected(config: str, expected_error: str, hash_value: str = expected_hash) -> None:
    try:
        MODULE.update_report_script_hash(config, hash_value)
    except ValueError as error:
        assert expected_error in str(error), (expected_error, str(error))
    else:
        raise AssertionError(f"an invalid shared-report CSP was accepted: {expected_error}")


rejected("server {}\n", "index alias")
rejected(report_config + report_config, "index alias")
rejected(report_config, "complete sha256 CSP token", "sha256-invalid")
rejected(
    report_config.replace(report_script_src, f"{report_script_src}; script-src '{foreign_hash}'"),
    "exactly one script-src",
)
rejected(
    report_config.replace(report_script_src, "script-src 'unsafe-inline'"),
    "only quoted sha256 hashes",
)
rejected(
    report_config.replace(report_script_src, "script-src 'self'"),
    "only quoted sha256 hashes",
)
rejected(
    report_config.replace(report_script_src, f"script-src '{old_hash}' https://example.org"),
    "only quoted sha256 hashes",
)
rejected(
    report_config.replace(report_script_src, f"script-src '{old_hash}' '{old_hash}'"),
    "duplicate sha256 hashes",
)
rejected(
    report_config.replace(report_csp_header, report_csp_header + report_csp_header, 1),
    "exactly one CSP header",
)
rejected(
    report_config.replace(report_csp_header, "", 1),
    "exactly one CSP header",
)
rejected(
    report_config.replace(
        report_csp_header,
        "        if ($request_method = GET) {\n"
        + report_csp_header.replace("        ", "            ", 1)
        + "        }\n",
        1,
    ),
    "not directly inside",
)
rejected(
    report_config.replace(report_script_src, "default-src 'none'"),
    "exactly one script-src",
)
rejected(report_config[:-2], "unmatched opening brace")
for required in (
    "alias /srv/cgv-cache/static_assets/releases/;",
    "limit_except GET HEAD { deny all; }",
    'add_header Cache-Control "public, max-age=31536000, immutable";',
    "disable_symlinks on from=/srv/cgv-cache/static_assets/releases;",
):
    assert required in snippet

with tempfile.TemporaryDirectory(prefix="cgv-nginx-candidate-") as temp_dir:
    temp = Path(temp_dir)
    config = temp / "server.conf"
    output = temp / "server.conf.candidate"
    config.write_text(base, encoding="utf-8")
    config.chmod(0o640)
    subprocess.run(
        [
            sys.executable,
            "-B",
            str(HELPER_PATH),
            "--config",
            str(config),
            "--snippet",
            str(SNIPPET_PATH),
            "--output",
            str(output),
        ],
        check=True,
    )
    assert output.read_text(encoding="utf-8") == inserted
    assert output.stat().st_mode & 0o777 == 0o640

    csp_config_path = temp / "server-with-csp.conf"
    csp_output = temp / "server-with-csp.conf.candidate"
    csp_config_path.write_text(report_config, encoding="utf-8")
    subprocess.run(
        [
            sys.executable,
            "-B",
            str(HELPER_PATH),
            "--config",
            str(csp_config_path),
            "--snippet",
            str(SNIPPET_PATH),
            "--output",
            str(csp_output),
            "--report-script-hash",
            expected_hash,
        ],
        check=True,
    )
    csp_candidate = csp_output.read_text(encoding="utf-8")
    assert csp_candidate == MODULE.build_candidate(expected_csp, snippet)

print("nginx static candidate: OK")
