# Deploy and Host OpenCode on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/opencode-cloud?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=opencode-cloud)

[OpenCode](https://opencode.ai) is the open-source AI coding agent: it reads your repo, edits files, runs commands and tests, and works with any model provider. This template runs its **web UI** on your Railway domain behind a password, on an always-on Ubuntu box with a full toolchain, so the agent keeps working when your laptop is closed and you can check in from any browser or phone. It works **the moment it deploys**: OpenCode's free Zen models need no API key.

## About Hosting OpenCode

One service, one volume. OpenCode 2's `opencode serve` (pinned version) runs on loopback behind nginx and serves the web UI and API; the generated server password protects every API call, terminal and event stream. The whole home directory `/root` is the volume, so sessions, provider logins, repos in `~/workspace`, GitHub auth and dotfiles survive every redeploy. The UI's built-in terminal tabs give you a real shell next to the chat. SSH through a Railway TCP proxy is there too, with host keys stored on the volume, and `oc` in that shell opens the OpenCode terminal UI attached to the same server, so the web UI and the TUI share sessions.

The box ships `git`, `gh`, Node 22, Python 3 + `uv`, `build-essential`, `ripgrep`, `fd`, `jq`, `tmux` and `vim`, so the agent can install dependencies, build and run your tests without extra setup.

## Common Use Cases

- Run long coding tasks 24/7 without keeping your laptop open, then review the diff from your phone
- Code from an iPad, Chromebook or a locked-down work machine: only a browser is needed
- Try OpenCode with free models first, then plug in Claude, GPT, Gemini, OpenRouter or a local gateway
- Give a small team one persistent agent workspace with the repos already cloned

## Dependencies for OpenCode Hosting

- None. Single service, no database. Model access: free OpenCode Zen models out of the box, or your own provider key.

### Deployment Dependencies

- [OpenCode docs](https://opencode.ai/docs/) and [source](https://github.com/anomalyco/opencode) (MIT)
- [OpenCode Zen](https://opencode.ai/docs/zen/) for the free and pay-as-you-go hosted models
- [GitHub CLI](https://cli.github.com/)

### Implementation Details

**First use:** open your Railway domain, choose **Use password**, keep the server address it fills in, and paste the generated `OPENCODE_SERVER_PASSWORD` from the service's Variables tab. The browser stays signed in across redeploys. Open `/root/workspace` as your project (or clone a repo there), pick a model and start typing. Models marked free under OpenCode Zen work immediately with no key; paid providers can be connected in the UI, via `opencode auth login` in the terminal, or by setting `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` or `OPENROUTER_API_KEY` on the service. Any other `*_API_KEY` variable you add (for example `GOOGLE_GENERATIVE_AI_API_KEY`, `GROQ_API_KEY`) is picked up too.

**GitHub:** set `GH_TOKEN` and `gh`, private `git clone` and `git push` just work (the box runs `gh auth setup-git` at boot). Or run `gh auth login` once in the terminal.

**SSH:** the template adds a TCP proxy for port 22. Copy the host and port from Settings → Networking and run `ssh root@<host> -p <port>` with `ROOT_PASSWORD`, or put your public key in `AUTHORIZED_KEYS` and clear `ROOT_PASSWORD` for key-only login. Type `oc` for the OpenCode terminal UI in the current directory.

**Upgrading OpenCode:** the version is pinned in the Dockerfile so every deploy is the build that was tested; this repo bumps it regularly and a redeploy picks it up. Your data is untouched by upgrades.

**Upgrading a deploy from OpenCode 1.x:** redeploy the service. Your sessions and their history carry over. The login changes from the browser's username/password popup to OpenCode's own sign-in page: choose **Use password** and paste the same `OPENCODE_SERVER_PASSWORD`. `OPENCODE_SERVER_USERNAME` is no longer used, and `oc` in SSH works as before. OpenCode 2 converts its database on first start, so going back to 1.x is not supported.

Notes and limits:

- Give the service at least 1 GB of RAM (the Trial plan's 1 GB is enough; the Free plan's 0.5 GB is not: OpenCode is OOM-killed on the first prompt, so on a service that small the template shows a page saying so instead of starting OpenCode). If the agent does run out of memory, OpenCode restarts by itself and the box stays up. OpenCode itself idles at about 110 MB and grows while the agent works; builds or test runs the agent starts need more.
- The agent runs as root with a shell. The web password is the lock: keep it strong and do not share the URL.
- Anything installed outside `/root` is lost on redeploy; put tools in `~/.local/bin` or reinstall them.
- There is no Docker daemon inside the box.

## Why Deploy OpenCode on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenCode on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
