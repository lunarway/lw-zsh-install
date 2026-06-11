# What you just installed — and why

`lunar-dev-setup.sh` gets a fresh Mac working in ~10 minutes, but it shouldn't be a black box. This is the 5-minute read on what each piece is for, so you can reason about your own setup — and fix it when something breaks months from now.

> **Something broken?** Run `zsh lunar-dev-setup.sh --doctor`. It checks every component below, explains what's wrong, and tells you how to fix it. Re-running the setup script itself is always safe — it's idempotent and only touches what's missing.

## The tools

**Homebrew** — macOS package manager. Everything else on this list is installed through it. If a tool is outdated or broken, `brew upgrade <tool>` or `brew reinstall <tool>` is usually the answer.

**Go** — the most used programming language at Lunar. Almost all backend services are Go. You'll find them under `~/lunar/` (services) with the Go toolchain in `~/go/`.

**git + GitHub CLI (`gh`)** — all Lunar code lives in the [lunarway](https://github.com/lunarway) GitHub org. `gh` handles browser-based authentication and lets you work with PRs from the terminal.

**lw-zsh** — Lunar's zsh setup ([lw-zsh-install](https://github.com/lunarway/lw-zsh-install), this repo). It installs and keeps the Lunar CLI toolbox on your PATH, including the three you'll use most:

- **`shuttle`** — Lunar's build/task runner. Every service repo has a `shuttle.yaml`; `shuttle run` builds, tests, and generates code the same way CI does. [Docs](https://backstage.lunar.tech/docs/default/Component/shuttle).
- **`hamctl`** — the CLI for [release-manager](https://github.com/lunarway/release-manager), Lunar's deployment system. It authenticates via Okta (`hamctl login`). When you're ready to ship, see [How to release services](https://backstage.lunar.tech/docs/default/component/tech-guides/releasing-services/).
- **`lunarctl`** — the platform CLI. Among other things it manages AI agent skills for your editors (`lunarctl agent skills doctor` / `select`).

## SSH keys: why two purposes, and why no passphrase

The script generated one key pair at `~/.ssh/github` and uploaded it to GitHub **twice** — once as an *authentication* key (to pull/push code) and once as a *signing* key (to sign commits). Both need SAML SSO authorization for the `lunarway` org, which is the one step the script can't do for you.

The key has **no passphrase** deliberately: `shuttle` runs Docker builds that pull private Go modules headlessly, and a passphrase prompt inside a Docker build just fails. For day-to-day terminal use the **1Password SSH agent** is layered on top — your `~/.ssh/config` tries the agent first (biometric auth, keys from the Employee vault) and falls back to the file key for Docker builds. Deep dive: [SSH keys](https://backstage.lunar.tech/docs/default/Component/developer-onboarding/ssh-keys/).

## Signed commits

Lunar requires signed commits. The script wrote `~/.gitconfig_lw` (your identity + SSH-key commit signing) and added `includeIf` rules to `~/.gitconfig` so this config applies **only** inside `~/lunar/` and `~/go/src/github.com/lunarway/` — your personal projects elsewhere are untouched. That's also why a repo cloned outside those folders will have unsigned commits rejected: move it under `~/lunar/`.

## What the script deliberately did NOT install

- **Node.js / npm** — only a few projects use Node (the most active is Houston, the customer support system). Install it only if you work on those; see [npm registry](https://backstage.lunar.tech/docs/default/Component/developer-onboarding/nodejs/).
- **An IDE** — your choice. VS Code, Cursor (install via Kandji), or JetBrains (license via [Company IT ticket](https://lunarway.atlassian.net/servicedesk/customer/portal/24)).
- **Docker** — see [Docker](https://backstage.lunar.tech/docs/default/Component/developer-onboarding/docker/) for the recommended setup.
- **VPN** — pre-configured via Kandji; ask #company-it if it's missing.

## Where to go next

- [Developer onboarding docs](https://backstage.lunar.tech/docs/default/Component/developer-onboarding/) — the full guide this script automates the mechanical parts of; worth skimming end-to-end.
- [AI tooling docs](https://github.com/lunarway/development-platform-docs/tree/master/docs/ai) — Claude Code, skills, cloud agents.
- [Backstage](https://backstage.lunar.tech) — all technical documentation.
- **#empower** on Slack — when you're stuck.
