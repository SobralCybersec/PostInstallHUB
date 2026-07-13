#!/usr/bin/env bash
# tools/dashboard.sh — Web dashboard for PostInstallHUB remote monitoring
#
# Usage:
#   # Terminal 1 — start dashboard first (picks a free port 8080-8099)
#   bash tools/dashboard.sh
#
#   # Terminal 2 — run installer (dashboard auto-captures output)
#   POSTINSTALL_YES=1 bash install.sh 2>&1 | tee /tmp/postinstallhub.log
#
# Or combined (dashboard auto-launches install):
#   bash tools/dashboard.sh --run [install args...]
#
# Features:
#   - Serves a self-contained HTML page (no external CDN deps) at http://localhost:PORT/
#   - SSE endpoint at /events streams install log lines in real-time
#   - HTML page auto-reconnects, shows colored log output (mirrors terminal colors)
#   - Shows distro, start time, current step, elapsed time
#   - Green/red status indicator (success/failure)
#   - "Copy log" button
#   - Works over SSH tunnel: ssh -L 8080:localhost:8080 user@server
#
# Implementation approach:
#   - Check for Python 3 first (most reliable cross-distro SSE server)
#   - Falls back to socat if available
#   - Minimum: requires Python 3 OR socat
#
# Log file: /tmp/postinstallhub.log (tee output here during install)
# PID file: /tmp/postinstallhub-dashboard.pid

set -euo pipefail

LOG_FILE="/tmp/postinstallhub.log"
PID_FILE="/tmp/postinstallhub-dashboard.pid"
HTML_FILE="/tmp/postinstallhub-dashboard.html"
SERVER_SCRIPT="/tmp/postinstallhub-server.py"
STATUS_FILE="/tmp/postinstallhub-status"

# ── port selection ────────────────────────────────────────────────────────────
find_free_port() {
    for port in $(seq 8080 8099); do
        if ! ss -ltn 2>/dev/null | grep -q ":${port} " && \
           ! lsof -i ":${port}" &>/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
    done
    echo "No free port in 8080-8099" >&2
    exit 1
}

# ── HTML generation ───────────────────────────────────────────────────────────
generate_html() {
    local port="$1"
    cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PostInstallHUB Dashboard</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #1a1a2e;
    color: #e0e0e0;
    font-family: system-ui, -apple-system, sans-serif;
    min-height: 100vh;
    padding: 1.5rem;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid #2a2a4e;
  }
  h1 { font-size: 1.4rem; color: #00d4ff; letter-spacing: 0.04em; }
  h1 span { color: #e0e0e0; font-weight: 400; font-size: 1rem; }
  .meta { font-size: 0.82rem; color: #888; display: flex; gap: 1.5rem; flex-wrap: wrap; }
  .meta b { color: #bbb; }
  .badge {
    padding: 0.3rem 0.9rem;
    border-radius: 999px;
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  .badge.running { background: #3a3000; color: #ffd700; border: 1px solid #ffd70044; }
  .badge.done    { background: #003a1a; color: #00e676; border: 1px solid #00e67644; }
  .badge.failed  { background: #3a0000; color: #ff5252; border: 1px solid #ff525244; }
  .controls {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }
  button {
    background: #2a2a4e;
    color: #00d4ff;
    border: 1px solid #00d4ff44;
    border-radius: 6px;
    padding: 0.35rem 0.9rem;
    font-size: 0.82rem;
    cursor: pointer;
    transition: background 0.15s;
  }
  button:hover { background: #1e3a4a; }
  #elapsed { font-size: 0.82rem; color: #888; margin-left: auto; }
  #log {
    background: #0d0d1a;
    border: 1px solid #2a2a4e;
    border-radius: 8px;
    padding: 1rem;
    font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    font-size: 0.82rem;
    line-height: 1.6;
    height: calc(100vh - 180px);
    overflow-y: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }
  #conn-indicator {
    width: 8px; height: 8px;
    border-radius: 50%;
    background: #ffd700;
    display: inline-block;
    margin-right: 0.4rem;
    vertical-align: middle;
  }
  #conn-indicator.connected { background: #00e676; }
  #conn-indicator.error     { background: #ff5252; }
</style>
</head>
<body>
<header>
  <div>
    <h1>PostInstallHUB <span>Dashboard</span></h1>
    <div class="meta" id="meta">
      <span><b>Host:</b> <span id="m-host">—</span></span>
      <span><b>Distro:</b> <span id="m-distro">detecting…</span></span>
      <span><b>Started:</b> <span id="m-start">—</span></span>
    </div>
  </div>
  <div id="badge" class="badge running">● Running</div>
</header>

<div class="controls">
  <span><span id="conn-indicator"></span><span id="conn-label">connecting…</span></span>
  <button id="btn-autoscroll" onclick="toggleScroll()">Auto-scroll ON</button>
  <button onclick="copyLog()">Copy Log</button>
  <span id="elapsed">0s</span>
</div>

<div id="log"></div>

<script>
  const logEl = document.getElementById('log');
  const badge = document.getElementById('badge');
  const indicator = document.getElementById('conn-indicator');
  const connLabel = document.getElementById('conn-label');
  let autoScroll = true;
  let startTime = Date.now();
  let lines = [];

  // meta
  document.getElementById('m-host').textContent = location.hostname;
  document.getElementById('m-start').textContent = new Date().toLocaleTimeString();

  // elapsed timer
  setInterval(() => {
    const s = Math.floor((Date.now() - startTime) / 1000);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    document.getElementById('elapsed').textContent =
      h ? `${h}h ${m}m ${sec}s` : m ? `${m}m ${sec}s` : `${sec}s`;
  }, 1000);

  // strip ANSI codes
  function stripAnsi(str) {
    return str.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '')
              .replace(/\x1b\][^\x07]*\x07/g, '')
              .replace(/\x1b[()][AB0-9]/g, '');
  }

  // colorize log line by prefix
  function colorize(line) {
    const c = {
      '[✓]': '#00e676', '[OK]': '#00e676', '[SUCCESS]': '#00e676',
      '[✗]': '#ff5252', '[ERROR]': '#ff5252', '[FAIL]': '#ff5252',
      '[!]': '#ffd700', '[WARNING]': '#ffd700', '[WARN]': '#ffd700',
      '[→]': '#00d4ff', '[STEP]': '#00d4ff', '[INFO]': '#bbb',
    };
    for (const [k, v] of Object.entries(c)) {
      if (line.includes(k)) {
        return `<span style="color:${v}">${escHtml(line)}</span>`;
      }
    }
    return escHtml(line);
  }

  function escHtml(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  function appendLine(raw) {
    const clean = stripAnsi(raw);
    lines.push(clean);

    // detect distro from line
    const dm = clean.match(/distro[:\s]+(\w+)/i) || clean.match(/\[STEP\].*?(\w+linux|\w+os|\w+)/i);
    if (dm) document.getElementById('m-distro').textContent = dm[1];

    const span = document.createElement('span');
    span.innerHTML = colorize(clean) + '\n';
    logEl.appendChild(span);
    if (autoScroll) logEl.scrollTop = logEl.scrollHeight;
  }

  function setStatus(s) {
    badge.className = 'badge ' + s;
    if (s === 'done')   badge.textContent = '✓ Done';
    if (s === 'failed') badge.textContent = '✗ Failed';
    if (s === 'running') badge.textContent = '● Running';
  }

  function toggleScroll() {
    autoScroll = !autoScroll;
    document.getElementById('btn-autoscroll').textContent =
      'Auto-scroll ' + (autoScroll ? 'ON' : 'OFF');
  }

  function copyLog() {
    navigator.clipboard.writeText(lines.join('\n')).then(() => {
      const btn = event.target;
      btn.textContent = 'Copied!';
      setTimeout(() => btn.textContent = 'Copy Log', 1500);
    });
  }

  // SSE
  function connect() {
    const evs = new EventSource('/events');

    evs.onopen = () => {
      indicator.className = 'connected';
      connLabel.textContent = 'connected';
    };

    evs.onmessage = (e) => {
      const data = JSON.parse(e.data);
      if (data.type === 'line') appendLine(data.text);
      if (data.type === 'status') setStatus(data.value);
      if (data.type === 'distro') document.getElementById('m-distro').textContent = data.value;
    };

    evs.onerror = () => {
      indicator.className = 'error';
      connLabel.textContent = 're-connecting…';
      evs.close();
      setTimeout(connect, 2000);
    };
  }

  connect();

  // poll status separately (catches done/failed even if SSE drops)
  setInterval(() => {
    fetch('/status').then(r => r.json()).then(d => {
      if (d.status !== 'running') setStatus(d.status);
    }).catch(() => {});
  }, 3000);
</script>
</body>
</html>
HTMLEOF
}

# ── Python SSE server ─────────────────────────────────────────────────────────
generate_server() {
    local port="$1"
    cat > "$SERVER_SCRIPT" << PYEOF
#!/usr/bin/env python3
"""PostInstallHUB SSE dashboard server. Python 3.6+ compatible."""
import http.server, json, os, sys, threading, time

LOG_FILE   = "/tmp/postinstallhub.log"
HTML_FILE  = "/tmp/postinstallhub-dashboard.html"
STATUS_FILE = "/tmp/postinstallhub-status"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

def read_status():
    try:
        return open(STATUS_FILE).read().strip()
    except FileNotFoundError:
        return "running"

def read_html():
    try:
        return open(HTML_FILE, "rb").read()
    except FileNotFoundError:
        return b"<h1>Dashboard HTML not found</h1>"

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # silence access log

    def do_GET(self):
        if self.path == "/":
            body = read_html()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/events":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("X-Accel-Buffering", "no")
            self.end_headers()
            self._stream_events()

        elif self.path == "/status":
            st = read_status()
            lines = 0
            try:
                lines = sum(1 for _ in open(LOG_FILE))
            except FileNotFoundError:
                pass
            body = json.dumps({"status": st, "lines": lines}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        else:
            self.send_response(404)
            self.end_headers()

    def _stream_events(self):
        def send(obj):
            msg = "data: " + json.dumps(obj) + "\n\n"
            self.wfile.write(msg.encode())
            self.wfile.flush()

        # replay existing log first
        pos = 0
        try:
            with open(LOG_FILE) as f:
                for line in f:
                    send({"type": "line", "text": line.rstrip("\n")})
                pos = f.tell()
        except FileNotFoundError:
            pass

        # tail new lines
        last_status = "running"
        try:
            while True:
                st = read_status()
                if st != last_status:
                    send({"type": "status", "value": st})
                    last_status = st

                try:
                    with open(LOG_FILE) as f:
                        f.seek(pos)
                        chunk = f.read()
                        if chunk:
                            for line in chunk.splitlines():
                                send({"type": "line", "text": line})
                            pos = f.tell()
                except FileNotFoundError:
                    pass

                if st in ("done", "failed"):
                    send({"type": "status", "value": st})
                    break

                # heartbeat keeps connection alive
                self.wfile.write(b": heartbeat\n\n")
                self.wfile.flush()
                time.sleep(0.5)
        except (BrokenPipeError, ConnectionResetError):
            pass

import socketserver
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
PYEOF
}

# ── cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
    local code="${1:-0}"
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -f "$SERVER_SCRIPT" "$HTML_FILE"
    # don't remove STATUS_FILE or LOG_FILE — user may want them after exit
    exit "$code"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    local run_install=0
    local install_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --run) run_install=1; shift; install_args=("$@"); break ;;
            -h|--help)
                grep '^#' "$0" | sed 's/^# *//' | head -20
                exit 0 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    # require python3
    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 required for the SSE server." >&2
        exit 1
    fi

    local port
    port="$(find_free_port)"

    # initialise status + log
    echo "running" > "$STATUS_FILE"
    touch "$LOG_FILE"

    generate_html "$port"
    generate_server "$port"

    python3 "$SERVER_SCRIPT" "$port" &
    local server_pid=$!
    echo "$server_pid" > "$PID_FILE"

    trap 'cleanup 130' INT TERM

    echo ""
    echo "  ┌─────────────────────────────────────────────┐"
    echo "  │  PostInstallHUB Dashboard                   │"
    echo "  │  http://localhost:${port}/                      │"
    echo "  │                                             │"
    echo "  │  SSH tunnel:                                │"
    echo "  │  ssh -L ${port}:localhost:${port} user@server    │"
    echo "  └─────────────────────────────────────────────┘"
    echo ""
    echo "  Log file : $LOG_FILE"
    echo "  Run installer in another terminal:"
    echo "    POSTINSTALL_YES=1 bash install.sh 2>&1 | tee $LOG_FILE"
    echo ""

    if [[ $run_install -eq 1 ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "$0")/.." && pwd)"
        echo "  Launching installer…"
        (
            POSTINSTALL_YES="${POSTINSTALL_YES:-1}" \
            bash "${script_dir}/install.sh" "${install_args[@]}" 2>&1 \
            | tee "$LOG_FILE"
            echo "${PIPESTATUS[0]}" > /tmp/postinstallhub-exit
        ) &
        local install_pid=$!

        wait "$install_pid" 2>/dev/null || true
        local exit_code=0
        [[ -f /tmp/postinstallhub-exit ]] && exit_code="$(cat /tmp/postinstallhub-exit)"
        rm -f /tmp/postinstallhub-exit

        if [[ "$exit_code" -eq 0 ]]; then
            echo "done" > "$STATUS_FILE"
            echo "  Install finished successfully."
        else
            echo "failed" > "$STATUS_FILE"
            echo "  Install FAILED (exit $exit_code)." >&2
        fi

        # give browser a moment to pick up final status before cleanup prompt
        sleep 2
        echo ""
        echo "  Press Ctrl+C to stop the dashboard server."
        wait "$server_pid" 2>/dev/null || true
        cleanup "$exit_code"
    else
        # standalone mode — wait for server (Ctrl+C to exit)
        wait "$server_pid" 2>/dev/null || true
        cleanup 0
    fi
}

main "$@"
