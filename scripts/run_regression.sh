#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../sim"
make clean
make vcs RUN_ARGS="+ntb_random_seed=${SEED:-7}"
