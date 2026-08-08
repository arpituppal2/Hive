#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hive.app"
TIMEOUT_SECONDS="${HIVE_SMOKE_TIMEOUT_SECONDS:-60}"
GRACEFUL_TEARDOWN="${HIVE_SMOKE_GRACEFUL_TEARDOWN:-0}"
APP_PID=""
APP_PGID=""
SHELL_PGID="$(ps -o pgid= -p $$ | tr -d '[:space:]')"
LOG_DIR=""
USER_DATA_DIR=""
STDOUT_LOG=""
STDERR_LOG=""
LIFECYCLE_REPORT="${HIVE_SMOKE_LIFECYCLE_REPORT:-}"
SESSION_EVIDENCE="${HIVE_SMOKE_SESSION_EVIDENCE:-0}"
readiness_seen=0

usage() {
  cat <<'USAGE'
Run the opt-in Hive bootstrap smoke test.

Usage:
  scripts/smoke-test-hive-app.sh [--app PATH]

Options:
  --app PATH       App bundle to launch (default: ./dist/Hive.app).
  -h, --help       Show this help.

Environment:
  HIVE_SMOKE_TIMEOUT_SECONDS    Readiness deadline in seconds (default: 60).
  HIVE_SMOKE_GRACEFUL_TEARDOWN  Set to 1 to exercise graceful CEF shutdown;
                                default 0 force-terminates only the owned
                                process group to avoid a known CEF teardown trap.
  HIVE_SMOKE_LIFECYCLE_REPORT   Optional caller-owned path for an atomic
                                diagnostic report written at readiness and
                                after teardown. The final report preserves both
                                stage records. It contains owned PIDs, helper
                                evidence, and readiness markers only; raw
                                page/model/runtime logs are omitted.
  HIVE_SMOKE_SESSION_EVIDENCE   Set to 1 for a two-launch isolated recovery
                                check. The first launch is force-terminated
                                after readiness; the second launch must report
                                restored session state, an unclean prior exit,
                                a positive durable tab count, and successful
                                snapshot writes. No URLs or page content are
                                emitted.

The harness also supplies an isolated CEF root/cache path and HOME to the app.
This is separate from Chromium's --user-data-dir because CEF configures profile
storage through rootCachePath/cachePath; HOME isolates Hive's session,
Honeycomb, hot-memory, and preference files as well. The app accepts the CEF
path override only for this explicit readiness-marker launch and only below the
OS temporary directory.

This proves bundle preflight and browser-shell bootstrap only. It does not
prove navigation, model inference, citations, voice permissions, approval
interaction, accessibility, or production signing/notarization.
USAGE
}

collect_descendants() {
  local parent="$1"
  local child
  for child in $(pgrep -P "$parent" 2>/dev/null || true); do
    echo "$child"
    collect_descendants "$child"
  done
}

signal_owned_processes() {
  local signal="$1"
  if [[ -n "$APP_PGID" && "$APP_PGID" != "$SHELL_PGID" ]]; then
    # Only use group signalling when the child has a distinct process group.
    # This prevents a non-job-control shell from killing itself.
    kill -"$signal" -- "-$APP_PGID" 2>/dev/null || true
    return
  fi

  # Bash/macOS may place a background child in the invoking shell's group.
  # In that case kill the known descendant tree only; never signal the shell's
  # process group. CEF helpers normally remain descendants of the app/helper
  # tree, and the final process wait bounds this fallback.
  local descendants
  descendants="$(collect_descendants "$APP_PID")"
  for pid in $descendants; do
    kill -"$signal" "$pid" 2>/dev/null || true
  done
  [[ -n "$APP_PID" ]] && kill -"$signal" "$APP_PID" 2>/dev/null || true
}

write_lifecycle_report() {
  local stage="$1"
  [[ -n "$LIFECYCLE_REPORT" ]] || return 0

  local report_dir report_tmp
  if [[ -L "$LIFECYCLE_REPORT" ]]; then
    echo "WARN: refusing to write lifecycle report through a symlink: $LIFECYCLE_REPORT" >&2
    return 0
  fi
  report_dir="$(dirname "$LIFECYCLE_REPORT")"
  report_tmp="${LIFECYCLE_REPORT}.tmp.$$"
  if ! mkdir -p "$report_dir" 2>/dev/null; then
    echo "WARN: could not create lifecycle report directory: $report_dir" >&2
    return 0
  fi

  # The report is intentionally caller-owned and must not live in either
  # harness-owned temporary tree; cleanup removes those trees after writing.
  # Resolve existing directories before comparing so a symlinked parent cannot
  # bypass the exclusion.
  local report_dir_real log_dir_real user_data_dir_real
  report_dir_real="$(cd "$report_dir" 2>/dev/null && pwd -P)"
  log_dir_real="$(cd "$LOG_DIR" 2>/dev/null && pwd -P)"
  user_data_dir_real="$(cd "$USER_DATA_DIR" 2>/dev/null && pwd -P)"
  if [[ -z "$report_dir_real" || -z "$log_dir_real" || -z "$user_data_dir_real" ]]; then
    echo "WARN: could not resolve lifecycle report paths; omitting report: $LIFECYCLE_REPORT" >&2
    return 0
  fi
  case "$report_dir_real/" in
    "$log_dir_real/"*|"$user_data_dir_real/"*)
      echo "WARN: lifecycle report path is inside a harness temp directory; omitting report: $LIFECYCLE_REPORT" >&2
      return 0
      ;;
  esac

  # This is diagnostic evidence, not a product log. Keep it bounded and omit
  # page/model output and raw runtime logs: process ownership and readiness
  # markers are sufficient for separating helper/lifecycle failures from the
  # smoke harness. Write-and-rename keeps readers from seeing a partial report.
  if ! {
    # Teardown preserves the readiness record so a host-capable run can be
    # compared without requiring a second sidecar file. The readiness write
    # starts a fresh report for each invocation.
    if [[ "$stage" == teardown-complete* && -f "$LIFECYCLE_REPORT" && ! -L "$LIFECYCLE_REPORT" ]]; then
      cat "$LIFECYCLE_REPORT"
      printf '%s\n' '--- next lifecycle stage ---'
    fi
    printf 'hive_lifecycle_report_version=1\n'
    printf 'stage=%s\n' "$stage"
    printf 'app_bundle=%s\n' "$(basename "$APP_PATH")"
    printf 'app_pid=%s\n' "${APP_PID:-none}"
    printf 'app_pgid=%s\n' "${APP_PGID:-none}"
    printf 'readiness_seen=%s\n' "$readiness_seen"
    printf 'graceful_teardown=%s\n' "$GRACEFUL_TEARDOWN"
    printf '%s\n' '--- owned process tree ---'
    if [[ -n "$APP_PID" ]]; then
      # Never persist full command lines: CEF arguments can contain paths,
      # profile locations, URLs, or future credentials. `comm` is executable
      # identity without argv content.
      printf '%s\n' 'pid ppid pgid stat executable'
      for pid in "$APP_PID" $(collect_descendants "$APP_PID"); do
        ps -o pid=,ppid=,pgid=,stat=,comm= -p "$pid" 2>/dev/null || true
      done
    else
      printf '%s\n' 'no app PID was recorded'
    fi
    printf '%s\n' '--- helper evidence ---'
    if [[ -n "$APP_PID" ]]; then
      helper_count=0
      for pid in "$APP_PID" $(collect_descendants "$APP_PID"); do
        executable="$(ps -o comm= -p "$pid" 2>/dev/null | sed 's#^.*/##' || true)"
        if [[ "$executable" == *'Helper'* || "$executable" == *'helper'* ]]; then
          printf '%s %s\n' "$pid" "$executable"
          helper_count=$((helper_count + 1))
        fi
      done
      printf 'helper_processes_observed=%s\n' "$helper_count"
    else
      printf '%s\n' 'helper_processes_observed=0'
    fi
    printf '%s\n' '--- readiness markers ---'
    grep -E '^HIVE_READINESS_(PASS|FAIL) ' "$STDOUT_LOG" 2>/dev/null | tail -4 || true
  } >"$report_tmp"; then
    rm -f "$report_tmp"
    echo "WARN: could not write lifecycle report: $LIFECYCLE_REPORT" >&2
    return 0
  fi
  mv -f "$report_tmp" "$LIFECYCLE_REPORT" 2>/dev/null || rm -f "$report_tmp"
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if [[ -n "$APP_PID" ]]; then
    if [[ "$GRACEFUL_TEARDOWN" == "1" ]]; then
      # Optional diagnostic mode only. The vendored CEF shutdown path can
      # trap while closing browsers under signal-driven termination; callers
      # who want to investigate that lifecycle may opt in explicitly.
      signal_owned_processes TERM
      sleep 1
      signal_owned_processes TERM
      sleep 1
    fi
    # Default teardown is forceful but scoped: signal only the distinct child
    # process group, or the known descendant tree fallback. This prevents a
    # smoke run from manufacturing a CEF shutdown crash while still ensuring
    # helper processes cannot survive the bounded test.
    signal_owned_processes KILL
    wait "$APP_PID" 2>/dev/null || true
  fi

  write_lifecycle_report "teardown-complete status=$status"

  if [[ "$status" -ne 0 ]]; then
    if [[ -n "$STDOUT_LOG" && -f "$STDOUT_LOG" ]]; then
      echo "--- Hive stdout ---" >&2
      tail -80 "$STDOUT_LOG" >&2 || true
    fi
    if [[ -n "$STDERR_LOG" && -f "$STDERR_LOG" ]]; then
      echo "--- Hive stderr ---" >&2
      tail -120 "$STDERR_LOG" >&2 || true
    fi
  fi
  [[ -z "$LOG_DIR" ]] || rm -rf "$LOG_DIR"
  [[ -z "$USER_DATA_DIR" ]] || rm -rf "$USER_DATA_DIR"
  return "$status"
}

# Install cleanup before allocation so even a partial mktemp/setup failure
# removes anything already created and never leaks a smoke profile.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hive-smoke.XXXXXX")"
USER_DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hive-user-data.XXXXXX")"
# Chromium's CEF cache is not the only state touched during browser-state
# bootstrap. Hive session, Honeycomb, hot memory, and preferences resolve from
# the user's home/Application Support. Redirect HOME to a private smoke home so
# a readiness run cannot read, lock, or mutate the developer's real browser.
mkdir -p "$USER_DATA_DIR/home"
STDOUT_LOG="$LOG_DIR/stdout.log"
STDERR_LOG="$LOG_DIR/stderr.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || { echo "ERROR: --app requires a path" >&2; exit 2; }
      APP_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Hive smoke test requires macOS (Darwin)." >&2
  exit 2
fi

if [[ ! "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: HIVE_SMOKE_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 2
fi

if [[ "$GRACEFUL_TEARDOWN" != "0" && "$GRACEFUL_TEARDOWN" != "1" ]]; then
  echo "ERROR: HIVE_SMOKE_GRACEFUL_TEARDOWN must be 0 or 1." >&2
  exit 2
fi

if [[ "$SESSION_EVIDENCE" != "0" && "$SESSION_EVIDENCE" != "1" ]]; then
  echo "ERROR: HIVE_SMOKE_SESSION_EVIDENCE must be 0 or 1." >&2
  exit 2
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: app bundle not found: $APP_PATH" >&2
  echo "Build it first with: scripts/build-hive-app.sh --allow-adhoc" >&2
  exit 2
fi

APP_PATH="$(cd "$APP_PATH" && pwd)"
APP_BINARY="$APP_PATH/Contents/MacOS/Hive"
if [[ ! -x "$APP_BINARY" ]]; then
  echo "ERROR: app executable not found or not executable: $APP_BINARY" >&2
  exit 2
fi

"$ROOT_DIR/scripts/preflight-hive-app.sh" --app "$APP_PATH" --allow-adhoc

echo "Launching: $APP_BINARY"
# Enable job control when the shell supports it so the app normally receives
# its own process group. The fallback below remains necessary for hosts that
# disallow job control (for example, some CI shells).
set -m 2>/dev/null || true

launch_app() {
  local output_mode="$1"
  APP_PID=""
  APP_PGID=""
  if [[ "$output_mode" == "append" ]]; then
    HOME="$USER_DATA_DIR/home" \
    HIVE_EMIT_READINESS_MARKER=1 \
    HIVE_EMIT_SESSION_EVIDENCE="$SESSION_EVIDENCE" \
    HIVE_CEF_ROOT_CACHE_PATH="$USER_DATA_DIR/CEF" \
      "$APP_BINARY" \
      --user-data-dir="$USER_DATA_DIR" \
      >>"$STDOUT_LOG" 2>>"$STDERR_LOG" &
  else
    HOME="$USER_DATA_DIR/home" \
    HIVE_EMIT_READINESS_MARKER=1 \
    HIVE_EMIT_SESSION_EVIDENCE="$SESSION_EVIDENCE" \
    HIVE_CEF_ROOT_CACHE_PATH="$USER_DATA_DIR/CEF" \
      "$APP_BINARY" \
      --user-data-dir="$USER_DATA_DIR" \
      >"$STDOUT_LOG" 2>"$STDERR_LOG" &
  fi
  APP_PID=$!
  CHILD_PGID="$(ps -o pgid= -p "$APP_PID" | tr -d '[:space:]')"
  if [[ -n "$CHILD_PGID" && "$CHILD_PGID" != "$SHELL_PGID" ]]; then
    APP_PGID="$CHILD_PGID"
  fi
}

is_live_process() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null || return 1
  local process_state
  process_state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
  [[ -n "$process_state" && "$process_state" != Z* ]]
}

wait_for_readiness() {
  local baseline="$1"
  local deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
  while [[ "$(date +%s)" -lt "$deadline" ]]; do
    local readiness_count
    readiness_count="$(grep -c '^HIVE_READINESS_PASS ' "$STDOUT_LOG" 2>/dev/null || true)"
    if [[ "$readiness_count" -gt "$baseline" ]]; then
      readiness_seen=1
      break
    fi
    if grep -q '^HIVE_READINESS_FAIL ' "$STDOUT_LOG" 2>/dev/null; then
      echo "FAIL: Hive reported readiness failure." >&2
      exit 1
    fi
    if grep -Eqi 'fatal|crash|CefSwift: failed|could not be located' "$STDERR_LOG" 2>/dev/null; then
      echo "FAIL: fatal runtime output detected." >&2
      exit 1
    fi
    if ! is_live_process "$APP_PID"; then
      echo "FAIL: Hive exited before readiness." >&2
      exit 1
    fi
    sleep 0.2
  done

  if [[ "$readiness_seen" -ne 1 ]]; then
    echo "FAIL: Hive readiness marker was not observed within ${TIMEOUT_SECONDS}s." >&2
    exit 1
  fi

  if ! is_live_process "$APP_PID"; then
    echo "FAIL: Hive exited immediately after readiness." >&2
    exit 1
  fi
}

launch_app ">"
wait_for_readiness 0
write_lifecycle_report "readiness launch=1"
echo "PASS: Hive emitted readiness within ${TIMEOUT_SECONDS}s."

if [[ "$SESSION_EVIDENCE" == "1" ]]; then
  first_sequence="$(grep '^HIVE_SESSION_EVIDENCE ' "$STDOUT_LOG" | tail -1 | sed -n 's/.*"snapshotSequence":\([0-9][0-9]*\).*/\1/p')"
  if [[ -z "$first_sequence" ]]; then
    echo "FAIL: first launch emitted no session evidence marker." >&2
    exit 1
  fi

  # Simulate an interrupted process, not a graceful quit. This deliberately
  # exercises the dirty-start recovery contract while keeping both launches in
  # one isolated profile. The cleanup trap still owns the final process.
  signal_owned_processes KILL
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""
  APP_PGID=""
  readiness_seen=0
  prior_readiness_count="$(grep -c '^HIVE_READINESS_PASS ' "$STDOUT_LOG" 2>/dev/null || true)"
  launch_app "append"
  wait_for_readiness "$prior_readiness_count"

  if ! grep -q '^HIVE_SESSION_EVIDENCE ' "$STDOUT_LOG"; then
    echo "FAIL: second launch emitted no session evidence marker." >&2
    exit 1
  fi
  second_evidence="$(grep '^HIVE_SESSION_EVIDENCE ' "$STDOUT_LOG" | tail -1)"
  if [[ "$second_evidence" != *'"restoredFromDisk":true'* ]]; then
    echo "FAIL: second launch did not report restoredFromDisk=true." >&2
    exit 1
  fi
  if [[ "$second_evidence" != *'"priorCleanExit":false'* ]]; then
    echo "FAIL: second launch did not report priorCleanExit=false." >&2
    exit 1
  fi
  if [[ "$second_evidence" != *'"writeSucceeded":true'* ]]; then
    echo "FAIL: second launch did not report writeSucceeded=true." >&2
    exit 1
  fi
  second_sequence="$(printf '%s\n' "$second_evidence" | sed -n 's/.*"snapshotSequence":\([0-9][0-9]*\).*/\1/p')"
  second_tab_count="$(printf '%s\n' "$second_evidence" | sed -n 's/.*"durableTabCount":\([0-9][0-9]*\).*/\1/p')"
  if [[ -z "$second_sequence" || "$second_sequence" -le "$first_sequence" ]]; then
    echo "FAIL: session snapshot sequence did not advance across relaunch." >&2
    exit 1
  fi
  if [[ -z "$second_tab_count" || "$second_tab_count" -le 0 ]]; then
    echo "FAIL: second launch did not report a positive durable tab count." >&2
    exit 1
  fi
  echo "PASS: two-launch session recovery evidence observed (sequence ${first_sequence} → ${second_sequence}, durable tabs ${second_tab_count}); no page content was inspected."
fi

write_lifecycle_report "readiness launch=2"
echo "PASS: This proves bundle/preflight/bootstrap readiness${SESSION_EVIDENCE:+ and isolated session recovery evidence}; it does not prove UI interaction, navigation, providers, citations, voice permissions, accessibility, or graceful CEF shutdown."
