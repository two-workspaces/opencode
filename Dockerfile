FROM ubuntu:24.04

# Bump OpenCode here (OpenCode 2, npm package @opencode/cli).
# upgrade: npm @opencode/cli
ARG OPENCODE_VERSION=2.2.5

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 PORT=8080 OPENCODE_DISABLE_AUTOUPDATE=1

# Toolbox the agent can use: git, gh, Node 22, Python 3 + uv, build tools, ripgrep, ssh server.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg git openssh-server nginx-light tmux \
      vim nano less htop ripgrep fd-find jq unzip zip tree procps sudo locales tini \
      python3 python3-pip python3-venv build-essential \
      iputils-ping dnsutils net-tools \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs gh \
  && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
  && npm install -g "@opencode/cli@${OPENCODE_VERSION}" && npm cache clean --force && opencode --version \
  && ln -s /usr/bin/fdfind /usr/local/bin/fd \
  # nginx `auto` sizes from the host's 48 cores on Railway, not the container's limit.
  && sed -i 's/^worker_processes .*/worker_processes 2;/' /etc/nginx/nginx.conf \
  && mkdir -p /run/sshd \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Skeleton for the persistent home (the volume mounts empty at /root on first boot).
COPY skel/ /opt/skel/
COPY entrypoint.sh /entrypoint.sh
COPY drop-file-cache oc /usr/local/bin/

EXPOSE 22 8080
# tini reaps zombies and forwards Railway's stop signal to the restart loop and OpenCode.
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/entrypoint.sh"]
