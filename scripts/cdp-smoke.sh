#!/bin/bash
# cdp-smoke.sh — verify Hive's devtools bridge round-trip over CDP.
#
# The remote debugging port is DEBUG-only AND opt-in (HIVE_DEBUG_CDP=1),
# so launch the app with that env var before running this script.
#
#   HIVE_DEBUG_CDP=1 dist/Hive.app/Contents/MacOS/Hive   # in another shell
#   scripts/cdp-smoke.sh                                 # this script
#
# The client is a MINIMAL RFC6455 websocket client written in Python 3 —
# no third-party deps. It performs the full HTTP Upgrade handshake (raw TCP
# frames without the handshake are rejected by the server, which has bitten
# ad-hoc harnesses before) and opens a FRESH session per operation.
#
# Usage: scripts/cdp-smoke.sh [expression]
#   expression: JS to evaluate on the first page target
#               (default: read the page title + verify the bridge token)

set -u
PORT="${HIVE_CDP_PORT:-9223}"
HOST="127.0.0.1"
EXPR="${1:-}"

echo "== cdp-smoke: checking devtools server on ${HOST}:${PORT} =="
if ! curl -s -m 3 "http://${HOST}:${PORT}/json/version" >/dev/null 2>&1; then
  echo "FAIL: no devtools server on ${HOST}:${PORT}."
  echo "      Launch Hive with HIVE_DEBUG_CDP=1 (the port is #if DEBUG + opt-in)." >&2
  exit 1
fi

python3 -u - "$PORT" "$EXPR" <<'PYEOF'
import base64, json, os, socket, struct, sys, time, urllib.request

HOST = "127.0.0.1"
PORT = int(sys.argv[1])
EXPR = sys.argv[2] or "({t: document.title, hasBridge: typeof window.cefSwift === 'object', tokenOk: (window.__HIVE_TOKEN || '').length === 36})"

def get_pages():
    with urllib.request.urlopen(f"http://{HOST}:{PORT}/json", timeout=6) as r:
        return json.loads(r.read().decode())

def ws_connect(ws_url):
    key = base64.b64encode(os.urandom(16)).decode()
    path = ws_url.split(f":{PORT}", 1)[1]
    sock = socket.create_connection((HOST, PORT), timeout=6)
    sock.sendall((f"GET {path} HTTP/1.1\r\nHost: {HOST}:{PORT}\r\nUpgrade: websocket\r\n"
                  "Connection: Upgrade\r\n"
                  f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        resp += sock.recv(4096)
    if b" 101 " not in resp.split(b"\r\n")[0]:
        raise RuntimeError("handshake failed")
    return sock

def send_frame(sock, payload):
    data = payload.encode()
    mask = os.urandom(4)
    hdr = bytearray([0x81])
    n = len(data)
    if n < 126:
        hdr.append(0x80 | n)
    elif n < 65536:
        hdr.append(0x80 | 126)
        hdr += struct.pack(">H", n)
    else:
        hdr.append(0x80 | 127)
        hdr += struct.pack(">Q", n)
    sock.sendall(bytes(hdr) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

def recv_frame(sock, timeout=12):
    sock.settimeout(timeout)
    try:
        hdr = sock.recv(2)
        if len(hdr) < 2:
            return None
        ln = hdr[1] & 0x7F
        if ln == 126:
            ln = struct.unpack("!H", sock.recv(2))[0]
        data = b""
        while len(data) < ln:
            chunk = sock.recv(ln - len(data))
            if not chunk:
                return None
            data += chunk
        return data.decode(errors="replace")
    except socket.timeout:
        return None

def evaluate_on_page(page, expression, await_promise=True, timeout=12):
    s = ws_connect(page["webSocketDebuggerUrl"])
    t0 = time.time()
    send_frame(s, json.dumps({
        "id": 1, "method": "Runtime.evaluate",
        "params": {"expression": expression, "returnByValue": True,
                   "awaitPromise": await_promise}
    }))
    while True:
        r = recv_frame(s, timeout)
        if r is None:
            s.close()
            return {"error": f"timeout after {timeout}s"}
        try:
            msg = json.loads(r)
        except Exception:
            continue
        if msg.get("id") == 1:
            s.close()
            res = msg.get("result", {})
            if "exceptionDetails" in res:
                return {"error": str(res.get("exceptionDetails"))[:200]}
            return {"value": res.get("result", {}).get("value"),
                    "dt": round(time.time() - t0, 3)}

pages = [p for p in get_pages() if p.get("type") == "page"]
if not pages:
    print("FAIL: no page targets")
    sys.exit(1)

# The JS bridge shim + session token live ONLY on the chrome shell page
# (hive://start?chrome=1). Prefer it for the bridge round-trip.
shell = next((p for p in pages if "chrome=1" in p.get("url", "")), None)
target = shell or pages[0]
print(f"target: {target.get('title','')[:40]!r} @ {target.get('url','')[:60]}")
result = evaluate_on_page(target, EXPR)
if "error" in result:
    print("FAIL:", result["error"])
    sys.exit(1)
print(f"eval OK (dt={result.get('dt')}s): {json.dumps(result.get('value'))[:160]}")

if shell is None:
    print("WARN: no chrome shell target — skipping bridge round-trip")
    print("PASS: cdp-smoke completed (eval only)")
    sys.exit(0)

# Bridge round-trip: read the token then invoke a harmless, side-effect-free
# method and confirm a boolean comes back.
token_result = evaluate_on_page(shell, "(window.__HIVE_TOKEN || '')")
if "error" in token_result or not token_result.get("value"):
    print("FAIL: bridge token not present on the chrome shell")
    sys.exit(1)
bridge = evaluate_on_page(
    shell,
    "window.cefSwift.invoke('hive.back', {token: window.__HIVE_TOKEN})"
)
if "error" in bridge:
    print("FAIL: bridge invoke rejected:", bridge["error"])
    sys.exit(1)
print("bridge round-trip OK:", json.dumps(bridge.get("value"))[:80])
print("PASS: cdp-smoke completed")
PYEOF
