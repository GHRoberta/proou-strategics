# SETUP — reconstruct the environment step by step

This guide takes a clean Windows machine to a working **Digital TPM Agent**.
Every step is something *you* do as yourself; the package ships no credentials.

---

## 0. Prerequisites

Install these first (all free / standard Microsoft tooling):

| Tool | Why | Install |
|---|---|---|
| **GitHub Copilot CLI** | the agent runtime | per your org's GitHub Copilot docs |
| **PowerShell 5.1+** | skills use Windows/PowerShell | ships with Windows |
| **Git** | cloning, version control | `winget install Git.Git` |
| **Azure CLI** | tokens for Power BI / Dataverse / MSX | `winget install Microsoft.AzureCLI` |
| **Python 3.11+** | script-backed skills | `winget install Python.Python.3.12` |
| **Node.js 18+** | HTML dashboard validation (jsdom) | `winget install OpenJS.NodeJS.LTS` |
| **Microsoft Edge** | browser-automation skills (Playwright) | preinstalled on Windows |

You also need a **Microsoft (Entra ID) work account** with access to the internal
services you intend to use (Agent365, MSX, the relevant Power BI reports, WorkIQ).
Access is granted to you as a user — it is **not** part of this package.

---

## 1. Get the package
Extract `Digital-TPM-Agent.zip` (or clone the repo) to a working folder, e.g.
`%USERPROFILE%\Digital-TPM-Agent`.

## 2. Install + personalize (one step, no file editing)
From the package folder, in PowerShell:

```powershell
cd $env:USERPROFILE\Digital-TPM-Agent
./setup.ps1
```

`setup.ps1` is interactive — it **asks you** for your name, alias, work email,
titles, time zone, and work dirs (press Enter to accept a sensible default),
auto-detects your Entra tenant from `az`, then:
- creates `~/.copilot` if missing;
- **backs up** any existing `agents/`, `skills/`, and the four config files to a
  timestamped `~/.copilot/_backup_<date>/`;
- copies `agents/*` and `skills/*` into `~/.copilot/` and **fills in every
  placeholder** with your values (identity, tenant, paths);
- writes the final `~/.copilot/copilot-instructions.md` and writes/merges
  `mcp-config.json`, `settings.json`, and `permissions-config.json`;
- seeds `workspace-scripts` into your synced work dir (never clobbering your data)
  and creates the local + synced work dirs.

Add `-InstallDeps` to also install the Python/Node libraries (section 6) in the
same run. Use `-WhatIf` for a dry preview.

> **Prefer to have the agent drive it?** Start `copilot` in this folder and say
> *"Read INSTALL.md and set up the Digital TPM Agent for me — ask me what you
> need."* It runs the same `setup.ps1` for you. See `INSTALL.md`.
>
> **Running non-interactively / scripting it?** Pass the values as parameters:
> `./setup.ps1 -NonInteractive -AgentName Nova -UserFullName "Alex Silva"
> -UserAlias alsilva -UserUpn alex.silva@example.com …` (full list: `Get-Help
> ./setup.ps1 -Detailed`).

You are **not** asked to open or edit any file — the two optional personal touches
(voice profile and managed portfolio) are covered in `PERSONALIZE.md` and can be
done by the agent afterwards.

## 3. MCP servers — what's already configured
`setup.ps1` already wrote `~/.copilot/mcp-config.json` with **your** tenant GUID and
paths filled in — you don't edit it. For reference, here's what each server needs to
work once you authenticate (section 4):

| Placeholder it filled | Meaning | Source |
|---|---|---|
| tenant GUID | your Entra tenant (in the Agent365 URLs) | `az account show --query tenantId -o tsv` |
| `~/.copilot` path | your Copilot home | `"$env:USERPROFILE\.copilot"` |

MCP servers included and what each needs:

| Server | Type | Auth / prereq |
|---|---|---|
| `microsoft-learn-docs` | http | none (public) |
| `powerbi-remote` | http (Fabric) | MS sign-in on first use |
| `agent365-mail` / `-calendar` / `-teams` / `-copilot-search` / `-user` / `-sharepoint` / `-word` | http | Agent365 access + MS sign-in; tenant in URL |
| `workiq` | stdio (local cmd) | the WorkIQ CLI on PATH + MS sign-in |
| `msx-mcp` | stdio (plugin) | install the MSX-MCP plugin (below) + `msx_login` |

**Install the MSX-MCP plugin** (Dataverse/MSX tools) per your org's instructions
for the `mcaps-microsoft/MSX-MCP` plugin, and **install the WorkIQ CLI**. The
generated `mcp-config.json` already points at the default locations
(`~/.copilot/installed-plugins/…/MSX-MCP` and `~/.copilot/bin/workiq.cmd`); if yours
differ, that's the only spot to adjust — otherwise these two servers just stay
offline and everything else works.

## 4. Authenticate
```powershell
az login                     # Power BI / Dataverse / MSX tokens
```
On first use, each Agent365/Power BI MCP server will prompt an interactive
Microsoft sign-in. For MSX, run the `msx_login` tool once. Nothing is cached in
the package — these tokens live only in your profile.

## 5. Python + Node dependencies
`setup.ps1 -InstallDeps` does this for you. To do it by hand (install more as a
skill prompts you):

```powershell
python -m pip install --upgrade pandas openpyxl python-pptx python-docx `
    beautifulsoup4 requests playwright deep-translator markitdown jsonschema
python -m playwright install msedge      # browser-automation skills
npm  install -g jsdom                    # or: npm i jsdom in your work dir
```

Your work dirs were already created by `setup.ps1`. To make one by hand:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\ghcli-working" | Out-Null
```

## 6. Verify it works
1. Start the CLI in your work folder and ask the agent: *"who are you and which
   skills do you have?"* — it should introduce itself with **your** agent name and
   list the skills.
2. Ask it to *"draft a test email to someone@example.com"* — confirm it writes a
   local `.eml` (per mandate M1) and does **not** touch your mailbox.
3. For the analytics pipeline: `cd "$env:USERPROFILE\OneDrive - Microsoft\ghcli-working\portfolio-analytics"; python
   healthcheck.py --offline` (after you've set your accounts in `portfolio_config.py`).
4. Re-run the anonymization check any time:
   `python sanitization/verify_no_pii.py "$env:USERPROFILE\.copilot"` (see `SANITIZATION.md`).

## Troubleshooting
- **MCP server won't start** — check the command path in `mcp-config.json` and that
  you're signed in (`az account show`); most http servers prompt sign-in lazily.
- **`az token failed`** — run `az login`.
- **A skill references a script you don't have** — some skills expect helper code in
  your work dir; `setup.ps1` seeds the flagship ones (cockpit, portfolio-analytics)
  there from `workspace-scripts/`.
- **Encoding errors printing emoji on Windows** — run Python with
  `$env:PYTHONIOENCODING='utf-8'` (scripts already self-configure where possible).
