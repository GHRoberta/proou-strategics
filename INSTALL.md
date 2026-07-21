# INSTALL — let the CLI agent install this for you (no file editing)

**You are the GitHub Copilot CLI agent reading this file. Follow it to install and
personalize the Digital TPM Agent for the human in front of you — by asking them
questions, not by telling them to edit files.**

If you are a human: open a terminal in this folder, start `copilot`, and type:

> **Read INSTALL.md and set up the Digital TPM Agent for me — ask me what you need.**

That's it. The agent takes it from here.

---

## Your job, agent (do these in order)

You will conduct a short interview, then run one PowerShell script (`setup.ps1`)
that does all the copying, token-filling, and config writing. **Never ask the user
to open or edit a file.** Ask one question at a time (use the `ask_user` tool when
available; otherwise ask in chat and wait).

### Step 0 — Check prerequisites (report, offer to fix)
Run these and tell the user what's present/missing. Do **not** fail the install if
some are missing — just note them for later.
```powershell
copilot --version; az version; python --version; node --version; git --version
```
If a required tool is missing, offer the winget command from `SETUP.md` §0. Only
`az`, `python`, and `node` matter for full functionality; the CLI itself is already
running.

### Step 1 — Auto-detect what you can (don't ask for these)
```powershell
az account show --query tenantId -o tsv      # -> TenantId (if signed in)
$env:USERPROFILE                             # -> home; COPILOT_HOME = <home>\.copilot
```
Derive silently: first/last name from the full name; the SharePoint segment from
the UPN (`alex.silva@example.com` -> `alex_silva_example_com`); the drafts dir.
If `az` isn't signed in, you'll ask for the tenant GUID in Step 2 (or tell them to
`az login` first — their choice).

### Step 2 — Interview (ask, don't assume — mandate M6)
Collect these. Show a sensible default in brackets and let them accept it. **Ask one
at a time.**

| Ask | Notes / default |
|---|---|
| **Agent name** | what it should answer to (e.g. *Nova*, *Atlas*). Required. |
| **Full name** | e.g. *Alex Pereira Silva*. Required. |
| **Signature / display name** | default = first + last. |
| **Corp alias** | e.g. *alsilva*. Required. |
| **Work email / UPN** | ends in `@microsoft.com`. Required. |
| **Job title (English)** | e.g. *Sr Learning & Skilling Manager*. |
| **Job title (Portuguese)** | e.g. *Gerente de Capacitação*. |
| **Short title** | for peer signatures, e.g. *TPM — Microsoft*. |
| **Time zone** | default *America/Sao_Paulo (GMT-03:00)*. |
| **Tenant GUID** | use the auto-detected value; only ask if detection failed. |
| **Local work dir** | drafts live here (mandate M1). Default `C:\ghcli-working`. |
| **Synced work dir** | cockpit + pipelines. Default `<home>\OneDrive - Microsoft\ghcli-working`. |

Do **not** ask for Entra object/role GUIDs — no skill needs them. Do **not** ask for
the voice openers/closers — the installer seeds neutral defaults and you'll offer a
real rebuild in Step 5.

Read the collected values back in one short summary and get a yes before running.

### Step 3 — Run the installer (this does everything, no editing)
Call `setup.ps1` non-interactively with the collected values. Quote every value.
```powershell
./setup.ps1 -NonInteractive `
  -AgentName '<agent>' `
  -UserFullName '<full name>' -UserName '<signature>' `
  -UserAlias '<alias>' -UserUpn '<upn>' `
  -UserTitleEn '<title EN>' -UserTitlePt '<title PT>' -UserTitleShort '<short>' `
  -UserTimezone '<tz>' -TenantId '<guid>' `
  -WorkdirLocal '<local dir>' -Workdir '<synced dir>'
```
It backs up any existing install, copies + personalizes `agents/` and `skills/` into
`~/.copilot`, writes `copilot-instructions.md`, and writes/merges `mcp-config.json`,
`settings.json`, and `permissions-config.json`. Report the summary it prints.

> Tip: run `./setup.ps1 -WhatIf ...` first if the user wants a preview. Add
> `-InstallDeps` to also install the Python/Node libraries in the same run.

### Step 4 — Authenticate as the user (the package ships no credentials)
Walk them through, don't do it silently:
1. `az login` (Power BI / Dataverse / MSX tokens).
2. On first use, each Agent365 / Power BI MCP server prompts a Microsoft sign-in —
   tell them to expect it.
3. For MSX, run the `msx_login` tool once.
The MSX-MCP plugin and the WorkIQ CLI must be installed per the org's instructions
(`SETUP.md` §4). If they're not present, the `msx-mcp` / `workiq` servers just won't
start — everything else still works. Offer to install deps now if not done:
```powershell
./setup.ps1 -InstallDeps
```

### Step 5 — Offer the personal touches (optional, ask first)
- **Voice profile.** Offer: *"Want me to rebuild your voice profile from your last
  ~150 Sent Items so drafts sound like you?"* If yes, and the mail MCP is connected,
  analyze and rewrite `~/.copilot/skills/my-voice/voice-profile.md` (and the EN one).
  Otherwise the neutral defaults stand.
- **Portfolio.** Offer to set their managed accounts in
  `<synced dir>\portfolio-analytics\portfolio_config.py` (the `PORTFOLIO` dict:
  `"TPID": ("Short name", "Vertical")`). Ask for the accounts; you edit the file —
  they don't.
- **Scrubbed third-party emails.** A few skill docs still read `{{EMAIL}}` where a
  *non-user* address was removed for privacy (a newsletter sender, an exception
  mailbox, partner contacts). Leave them; when a skill actually needs one, ask the
  user for that specific address at that moment — never guess (mandate M6).

### Step 6 — Verify
```powershell
python sanitization/verify_no_pii.py "$env:USERPROFILE\.copilot"
```
Then confirm the agent is live: start a fresh `copilot` session in the work dir and
ask *"who are you and which skills do you have?"* — it should introduce itself with
the chosen agent name. If the analytics pipeline is wanted:
`cd '<synced dir>\portfolio-analytics'; python healthcheck.py` (after portfolio is set).

---

## Guardrails
- **Never tell the user to edit a file.** If something needs a value, ask for it and
  make the change yourself.
- **Never invent** an email, GUID, path, or customer. If you don't have it and can't
  detect it, ask (mandate M6).
- **Never send anything.** Every email/message this agent produces is a local draft
  the user reviews (mandates M1/M2). The install itself sends nothing.
- **Back up, don't clobber.** `setup.ps1` already backs up an existing install and
  never overwrites the user's `portfolio_config.py` or work-dir data.
