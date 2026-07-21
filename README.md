# Digital TPM Agent

A portable, **fully anonymized** package that turns a fresh **GitHub Copilot CLI**
install into a capable "digital self" for a **Technical Program Manager (TPM)** at
Microsoft — the same agents, skills, and standing rules, with **your** identity
plugged in.

This package contains **no credentials and no personal or customer data**. Every
name, alias, UPN, tenant, TPID, GUID, phone, email, and machine path has been
replaced with a `{{PLACEHOLDER}}` or `[TOKEN]`. You make it *yours* in one
personalization pass (see **`PERSONALIZE.md`**).

---

## What's inside

```
Digital-TPM-Agent/
├── README.md                     ← you are here
├── INSTALL.md                    ← let the CLI agent install it by asking you questions
├── setup.ps1                     ← installer: copies + personalizes, no file editing
├── install.ps1                   ← compatibility shim → setup.ps1
├── SETUP.md                      ← manual, step-by-step reconstruction (reference)
├── PERSONALIZE.md                ← what gets filled in + optional personal touches
├── copilot-instructions.template.md   ← the "standing mandates" (generalized)
├── config/
│   ├── mcp-config.template.json         ← 11 MCP servers (tenant/paths = placeholders)
│   ├── settings.template.json
│   └── permissions-config.template.json
├── agents/            ← 12 custom agents (*.agent.md)
├── skills/            ← 45 skills (SKILL.md + helper scripts)
├── workspace-scripts/ ← support code for script-backed skills (cockpit, portfolio-analytics)
└── sanitization/      ← how it was anonymized + a re-verification tool
```

- **12 agents** — meeting prep, MEDDPICC opportunity review, secure email drafter,
  Word composer, training requester/designer, customer digest, dashboards, and more.
- **45 skills** — office docs (docx/pptx/xlsx), MSX/Dataverse tooling, Power BI
  usage/ACR, ESI training catalog, adoption playbooks, voice profiles, cockpit,
  portfolio analytics, and utilities.
- **11 MCP servers** — WorkIQ, Power BI (Fabric), Microsoft Learn, six Agent365
  M365 tools (mail/calendar/teams/search/user/sharepoint/word), and MSX-MCP.

## Quick start — you never edit a file

Pick either path. Both fill in **your** identity, tenant, and paths for you and
write the final configs; neither asks you to open a template.

### Option 1 — let the agent do it (recommended)
Install the [GitHub Copilot CLI](https://docs.github.com/copilot), then from this
folder:

```powershell
copilot
```
…and tell it:

> **Read INSTALL.md and set up the Digital TPM Agent for me — ask me what you need.**

The agent interviews you (name, alias, work email, titles…), auto-detects your
tenant and paths, runs the installer, and walks you through signing in. It follows
`INSTALL.md`.

### Option 2 — run the installer yourself
```powershell
./setup.ps1            # interactive: it asks you everything (Enter accepts a default)
./setup.ps1 -WhatIf    # preview only, changes nothing
```
`setup.ps1` backs up any existing install, copies **agents + skills** into
`~/.copilot`, fills every placeholder, and writes the final
`copilot-instructions.md`, `mcp-config.json`, `settings.json`, and
`permissions-config.json`. Add `-InstallDeps` to also install the Python/Node
libraries.

### Then, once (as yourself)
```powershell
az login                       # Power BI / Dataverse / MSX tokens
```
Sign in to each MCP server on first use; run `msx_login` once for MSX. Optionally
ask the agent to rebuild your voice profile from your Sent Items and to set your
managed accounts. Details in `SETUP.md` (§4–§6) and `PERSONALIZE.md`.

## Requirements at a glance

- Windows + PowerShell 5.1+ (skills assume Windows paths).
- A Microsoft (Entra ID) work account with access to the relevant internal
  services (Agent365, MSX, Power BI reports, WorkIQ). Access is **per-user** — this
  package ships none of it.
- GitHub Copilot CLI, Azure CLI, Python 3.11+, Node.js 18+ (and Microsoft Edge for
  the browser-automation skills).

> **Nothing here works until *you* authenticate as yourself.** The package is
> logic + instructions only; all data and access remain your own.

See **`SANITIZATION.md`** for exactly what was stripped and how to re-verify.
