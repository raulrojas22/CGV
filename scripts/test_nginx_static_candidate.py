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
old_hash = "sha256-VJ57di/IQ0e4GQS4gxb2N0MxDIJ1cTW0ycxWaMfXqog="
new_hash = "sha256-EXkIJnQvs/u+7Sw8WFMz21f46Zk6qxolUQbZIaQ9yfg="
csp_config = (
    "add_header Content-Security-Policy \"default-src 'none'; "
    f"script-src '{old_hash}'; connect-src 'none'\" always;\n"
)
updated_csp = MODULE.update_report_script_hash(csp_config, new_hash)
assert new_hash in updated_csp and old_hash not in updated_csp
for invalid_config, invalid_hash in (
    ("server {}\n", new_hash),
    (csp_config + csp_config, new_hash),
    (csp_config, "sha256-invalid"),
):
    try:
        MODULE.update_report_script_hash(invalid_config, invalid_hash)
    except ValueError:
        pass
    else:
        raise AssertionError("an invalid shared-report CSP update was accepted")
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
    csp_config_path.write_text(base.replace("server {\n", "server {\n    " + csp_config), encoding="utf-8")
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
            new_hash,
        ],
        check=True,
    )
    csp_candidate = csp_output.read_text(encoding="utf-8")
    assert new_hash in csp_candidate and old_hash not in csp_candidate

print("nginx static candidate: OK")
