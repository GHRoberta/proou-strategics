# PERSONALIZE — make it *your* digital self

**You don't edit any files.** `setup.ps1` (or the agent, via `INSTALL.md`) fills in
all your identity/path/tenant values during install. This page is a **reference** of
what gets filled, plus the two optional personal touches — **(B)** your voice profile
and **(C)** your managed portfolio — which the agent can also do for you afterwards.

---

## A. What the installer fills for you (reference only)

You are asked for a handful of values (name, alias, work email, titles, time zone,
work dirs); the tenant and paths are auto-detected/derived. The installer then
replaces these tokens everywhere and writes the final `copilot-instructions.md` and
config files — you never open a template.

| Token | What it is | Example |
|---|---|---|
| `{{AGENT_NAME}}` | the name your agent answers to | `Nova`, `Atlas`, `TPM-Bot` |
| `{{USER_NAME}}` | your display/signature name | `Alex Silva` |
| `{{USER_FULL_NAME}}` | your full legal name | `Alex Pereira Silva` |
| `{{USER_FIRSTNAME}}` / `{{USER_LASTNAME}}` | name parts | `Alex` / `Silva` |
| `{{USER_ALIAS}}` | your corp alias | `alsilva` |
| `{{USER_UPN}}` | your work email (ends in @microsoft.com) | `alex.silva@example.com` |
| `{{USER_SP}}` | SharePoint/OneDrive user segment | `alex_silva_microsoft_com` |
| `{{USER_TITLE_EN}}` / `{{USER_TITLE_PT}}` / `{{USER_TITLE_SHORT}}` | your titles | `Sr Learning & Skilling Manager` … |
| `{{USER_TIMEZONE}}` | your TZ | `America/Sao_Paulo (GMT-03:00)` |
| `{{TENANT_ID}}` | your Entra tenant GUID | `az account show --query tenantId -o tsv` |
| `{{USER_OBJECT_ID}}` / `{{USER_TPM_GUID}}` | your Entra/role GUIDs (only if a skill needs them) | from your profile |
| `{{COPILOT_HOME}}` | `~/.copilot` absolute path | `%USERPROFILE%\.copilot` |
| `{{USERPROFILE}}` | your home dir | `%USERPROFILE%` |
| `{{WORKDIR}}` | your synced work dir (if used) | `%USERPROFILE%\OneDrive - Microsoft\ghcli-working` |
| `{{WORKDIR_LOCAL}}` | your **local** work dir (drafts, per mandate M1) | `C:\ghcli-working` |
| `{{EMAIL}}` | a real email that was scrubbed — replace with the correct address, or delete | — |
| `[CLIENTE]` / `[CONTATO]` / `[TPID]` | a customer name / contact / account id that was scrubbed from an **example** — replace with your own example or leave as a generic label | — |

### Advanced: re-run or override
To change a value later, just re-run the installer — it rebuilds from the pristine
package and backs up the previous install first:

```powershell
./setup.ps1                       # interactive, asks again
./setup.ps1 -NonInteractive -AgentName Nova -UserUpn you@example.com …   # scripted
```

`{{USER_OBJECT_ID}}` / `{{USER_TPM_GUID}}` are **not** requested — no skill uses them.

---

## B. Build your voice profile (optional, agent-assisted)
The installer seeds **neutral** openers/closers so nothing is left blank. To make it
sound like *you*, ask the agent (recommended) — you don't edit the file:

> *"Analyze my last ~150 Sent Items and rebuild my-voice/voice-profile.md with my
> real signatures, openers/closers, audience modes and language routing."*

It updates `~/.copilot/skills/my-voice/voice-profile.md` (and the EN one) and shows
you the result before keeping it. Requires your mailbox MCP to be connected.

---

## C. Set your managed portfolio (optional, agent-assisted)
Tell the agent your accounts and it sets them in
`…\ghcli-working\portfolio-analytics\portfolio_config.py` (the `PORTFOLIO` dict:
`"TPID": ("Short name", "Vertical")`, TPIDs from MSX) — you don't edit the file. The
installer never overwrites this file if you've already populated it. Other IDs in it
are shared Microsoft report/dataset identifiers and stay as-is.

Skills that track accounts (cockpit cards, customer aliases, digests) start
**empty** on purpose — populate them with your own accounts as you go.

---

## D. Final check
Run the anonymization scan again after personalizing to confirm you didn't paste
anything you didn't mean to share (see `SANITIZATION.md`):

```powershell
python sanitization/verify_no_pii.py "$env:USERPROFILE\.copilot"
```
