#!/bin/bash
set -e
: "${OPENCODE_SERVER_PASSWORD:?OPENCODE_SERVER_PASSWORD is required - it is the only lock on this box}"

# Railway's Free plan caps a service at 0.5 GB, and OpenCode is OOM-killed on the
# first prompt there. Railway counts each kill as a failed deploy, so on a service
# under ~1 GB serve a page saying what's needed instead of starting OpenCode.
mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo max)
if [ "$mem" != max ] && [ "$mem" -lt $((900 * 1024 * 1024)) ] 2>/dev/null; then
  mkdir -p /run/gate
  cat > /run/gate/index.html <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>OpenCode needs more memory</title><style>body{font:16px/1.5 system-ui,sans-serif;max-width:40rem;margin:3rem auto;padding:0 1rem}</style></head>
<body><h1>OpenCode needs at least 1 GB of memory</h1>
<p>This service is limited to $((mem / 1024 / 1024)) MB, which is Railway's Free plan. OpenCode starts there but is killed as soon as the agent works, so it hasn't been started.</p>
<p>The Trial plan (1 GB) runs it, and Hobby gives agents room for builds and tests. Upgrade, then redeploy this service.</p></body></html>
HTML
  cat > /etc/nginx/sites-enabled/default <<CFG
server {
  listen ${PORT} default_server;
  listen [::]:${PORT} default_server;
  root /run/gate;
  location = /healthcheck { return 200 "ok"; }
  location / { try_files /index.html =404; }
}
CFG
  echo "== memory limit $((mem / 1024 / 1024)) MB is under the 1 GB OpenCode needs; serving instructions on :${PORT} instead"
  exec nginx -g 'daemon off;'
fi

# /root is a Railway volume: empty on first boot, root-owned. Seed dotfiles once
# (flag file, not per-file checks: local docker pre-copies the image's /root into a
# fresh volume, which would otherwise shadow our skel).
if [ ! -f /root/.opencode-box-seeded ]; then
  cp -af /opt/skel/. /root/ && touch /root/.opencode-box-seeded
fi
mkdir -p /root/.ssh /root/workspace && chmod 700 /root/.ssh
# Volumes seeded before OpenCode 2 define an `oc` shell function on `opencode attach`,
# which 2.x dropped; it would shadow /usr/local/bin/oc.
sed -i '/^# `oc` = the OpenCode terminal UI attached/,/^oc() { opencode attach .*}$/d' /root/.bashrc

# Persist SSH host keys on the volume so clients don't see "host key changed" after redeploys.
mkdir -p /root/.ssh-host
for t in rsa ed25519; do
  [ -f "/root/.ssh-host/ssh_host_${t}_key" ] || ssh-keygen -q -t "$t" -N '' -f "/root/.ssh-host/ssh_host_${t}_key"
  cp -f "/root/.ssh-host/ssh_host_${t}_key" "/root/.ssh-host/ssh_host_${t}_key.pub" /etc/ssh/
  chmod 600 "/etc/ssh/ssh_host_${t}_key"
done

# Root login: password from ROOT_PASSWORD, optional keys from AUTHORIZED_KEYS.
[ -n "${ROOT_PASSWORD:-}" ] && echo "root:${ROOT_PASSWORD}" | chpasswd
[ -n "${AUTHORIZED_KEYS:-}" ] && printf '%s\n' "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/railway.conf <<CFG
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PasswordAuthentication $([ -n "${ROOT_PASSWORD:-}" ] && echo yes || echo no)
ClientAliveInterval 60
CFG
/usr/sbin/sshd

# sshd strips the environment: hand provider keys, tokens and the server login to SSH
# sessions too (so `oc` can attach to the running server). %q quotes any value safely.
for v in $(compgen -e | grep -E '_API_KEY$|^OPENCODE_|^(GH_TOKEN|GITHUB_TOKEN|TZ|PORT)$'); do
  printf 'export %s=%q\n' "$v" "${!v}"
done > /etc/profile.d/railway-env.sh

# git push over https with GH_TOKEN, no interactive login.
[ -n "${GH_TOKEN:-}" ] && gh auth setup-git >/dev/null 2>&1 || true

# nginx on $PORT: /healthcheck answers only once opencode's API does; everything else
# goes to opencode, whose API needs the server password (web login, pairing link or
# basic auth as user `opencode`). SSE + PTY websockets: no buffering.
AUTH=$(printf 'opencode:%s' "$OPENCODE_SERVER_PASSWORD" | base64 -w0)
cat > /etc/nginx/sites-enabled/default <<CFG
server {
  listen ${PORT} default_server;
  listen [::]:${PORT} default_server;
  client_max_body_size 100m;
  location = /healthcheck {
    proxy_pass http://127.0.0.1:4096/api/info;
    proxy_set_header Authorization "Basic ${AUTH}";
  }
  location / {
    proxy_pass http://127.0.0.1:4096;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    proxy_set_header Host \$host;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 1d;
    proxy_send_timeout 1d;
  }
}
CFG
nginx

# Railway counts the kernel's cache of files this container has touched as the
# service's memory, and with no memory pressure it is never freed: one npm
# install shows as hundreds of MB. Drop it for the home volume every 15 min.
( while sleep 900; do nice -n 19 drop-file-cache /root /tmp || true; done ) &

echo "== opencode box ready: web UI on :${PORT}, sshd on :22, $(opencode --version)"
cd /root/workspace
# With OPENCODE_SERVER_PASSWORD set, serve does not print the password.
# Not exec'd: if the kernel OOM-kills OpenCode mid-task, the container stays up
# (and so do sshd and the volume's work) and OpenCode comes back on its own.
while :; do
  opencode serve --hostname 127.0.0.1 --port 4096 || true
  echo "== opencode exited; restarting in 2 s"
  sleep 2
done
