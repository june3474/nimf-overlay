#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

python3 "$repo_root/tests/test_static_layout.py"
bash "$repo_root/tests/test_eselect.sh"
bash "$repo_root/tests/test_artifact_pipeline.sh"
