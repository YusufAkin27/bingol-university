#!/usr/bin/env bash
# last-success.json ve backup_remote.prom'u yerel/uzak durumla yeniden yazar (ag erisimi yok; yalniz yerel dosyalar).
# Kullanim: status-refresh.sh      (entrypoint acilista ve elle)
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
status_enrich
metric_remote_write
