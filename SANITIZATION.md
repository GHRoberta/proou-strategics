# SANITIZATION — what was removed and how to re-verify

This package was built from a working TPM environment and then **fully
anonymized**. This document states exactly what was stripped, what was kept, and
how to re-check.

## Guarantee
- **No credentials.** No tokens, keys, OAuth caches, `.enc` files, browser auth
  profiles, cookies, or session/DB files are included.
- **No personal data.** No user name, alias, UPN, email, phone, SharePoint id,
  Entra tenant/object GUIDs, or machine paths.
- **No customer data.** No account names, TPIDs, opportunity/account GUIDs,
  contact names, cockpit cards, digests, or pipeline outputs.

Everything above was replaced with a `{{PLACEHOLDER}}` or a generic label
(`[CLIENTE]`, `[CONTATO]`, `[TPID]`), or excluded entirely.

## What was EXCLUDED entirely (not shipped)
- All credential/state files from `~/.copilot` (memory, sessions, caches, tokens,
  OAuth config, encryption keys, databases).
- All **data / output / cache** directories inside skills (e.g. weekly digest
  data & outputs, `_cache`, dated `YYYY-Www` folders, cockpit cards).
- All non-text/data/binary files: `.json` data, `.jsonl`, `.csv`, `.xlsx`,
  images, `.pptx/.pdf/.mp4`, `.eml`, `.html` outputs, `.db`, `.enc`, `.zip`, logs.
- The 586 MB **Copilot Success Kit** decks — only its `SKILL.md` + helper scripts
  ship, with a note to download the official assets from Microsoft.
- The personal **voice profiles** — shipped as blank templates instead.
- `pipeline_data.py` (a personal data snapshot) and the real `PORTFOLIO` account
  list (replaced with example rows).

## What was KEPT (and is safe)
- Skill/agent **logic** (`SKILL.md`, `*.agent.md`, helper `.py/.ps1/.js`).
- **Shared Microsoft artifact identifiers** that are the same for every user
  (public Power BI dataset/report IDs, app IDs, MCP endpoint URLs). These are not
  personal; skills need them to work. Your Entra **tenant** GUID is a placeholder.

## How it was done (reproducible)
An exclude-first, then scrub pipeline:
1. **Exclude** data/output/cache/binary/credential files and template-only skills.
2. **Scrub** every remaining text file: emails -> `{{EMAIL}}`; identity
   (name/alias/UPN/agent-name) -> `{{…}}`; Windows paths -> `{{…}}`; tenant/object
   GUIDs -> `{{…}}`; TPIDs -> `[TPID]`; customer names -> `[CLIENTE]`; contacts ->
   `[CONTATO]`. Common Portuguese/English words that happen to be brand names
   (via, vale, porto, caixa…) are scrubbed only in their capitalized proper-noun
   form to avoid corrupting prose.
3. **Verify** the whole tree against a denylist (identity + customer names +
   TPIDs + GUIDs + email/phone/path patterns) and iterate to **zero** hits.

Result of the final build: **0 hard hits, 0 soft hits.**

## Re-verify yourself
A generic scanner ships in this folder (no embedded personal data):

```powershell
# scan the package (or your installed ~/.copilot after personalizing)
python sanitization/verify_no_pii.py .
python sanitization/verify_no_pii.py "$env:USERPROFILE\.copilot" --denylist my_terms.txt
```

`--denylist my_terms.txt` (one term per line) lets you add your own name, alias,
and customer names to confirm none leaked back in after you personalized.
