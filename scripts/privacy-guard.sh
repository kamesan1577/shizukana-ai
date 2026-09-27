#!/usr/bin/env bash
set -euo pipefail
# Inventory explicit application-controlled transfers. Apple framework usage is allowed.
if rg -n 'URLSession|import Network|WKWebView|CloudKit|Firebase|Analytics|Crashlytics|https?://|api[_-]?key' App/Sources Core/Sources --glob '*.swift'; then
  echo 'Unreviewed application-controlled network path: document destination, fields, purpose and retention in SECURITY.md' >&2
  exit 1
fi
if rg -n 'print\(|NSLog\(|os_log\(' App/Sources Core/Sources --glob '*.swift'; then
  echo 'Release logging requires privacy review' >&2
  exit 1
fi
