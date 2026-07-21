<#
.SYNOPSIS
  Installs AND personalizes the Digital TPM Agent into ~/.copilot — with no manual
  file editing. It copies the agents + skills, fills in every {{PLACEHOLDER}} with
  your details, and writes the final config files ready to use.

.DESCRIPTION
  This is the single installer. Run it two ways:

    # 1. Interactive — it asks you everything (recommended for humans):
    ./setup.ps1

    # 2. Non-interactive — pass answers as parameters (used by the CLI agent
    #    when it runs the install for you, see INSTALL.md):
    ./setup.ps1 -NonInteractive -AgentName Nova -UserFullName "Alex Silva" `
        -UserUpn alex.silva@example.com -UserAlias alsilva `
        -UserTitleEn "Sr Learning & Skilling Manager" -UserTitlePt "Gerente de Capacitação"

    # Preview only, change nothing:
    ./setup.ps1 -WhatIf

  What it does (idempotent — always builds from the pristine package):
    1. Backs up any existing agents/, skills/ and the four config files.
    2. Copies agents/* and skills/* into ~/.copilot.
    3. Replaces every identity/path/tenant token across the installed tree.
    4. Writes ~/.copilot/copilot-instructions.md (from template, admonition removed).
    5. Writes/merges mcp-config.json, settings.json, permissions-config.json.
    6. Seeds workspace-scripts into your work dir (only files that don't exist yet).
    7. Creates the local + synced work dirs (and drafts/).
    8. Prints what to do next (authenticate, optional deps). NEVER asks you to
       edit a file.

.NOTES
  Nothing here contains credentials. You still authenticate as yourself afterwards
  (az login, MCP first-use sign-in, msx_login). See SETUP.md sections 5-7.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AgentName,
    [string]$UserFullName,
    [string]$UserName,          # signature / display name; default = first + last
    [string]$UserAlias,
    [string]$UserUpn,           # your @microsoft.com work address
    [string]$UserTitleEn,
    [string]$UserTitlePt,
    [string]$UserTitleShort,
    [string]$UserTimezone,
    [string]$TenantId,          # auto-detected from `az` if you don't pass it
    [string]$WorkdirLocal,      # local drafts dir (mandate M1); default C:\ghcli-working
    [string]$Workdir,           # synced work dir; default ~\OneDrive - Microsoft\ghcli-working
    [string]$CopilotHome = (Join-Path $env:USERPROFILE '.copilot'),
    [switch]$InstallDeps,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$pkg = $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)   # UTF-8, no BOM

function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$t) {
    $dir = Split-Path -Parent $p
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($p, $t, $enc)
}

# -- prompt helper: uses a supplied value, else the default; asks only when interactive
function Get-Val([string]$current, [string]$label, [string]$default, [switch]$Required) {
    if ($current) { return $current }
    if ($NonInteractive) {
        if ($Required -and -not $default) { throw "Missing required value: $label. Pass -$($label -replace '\s','') or run without -NonInteractive." }
        return $default
    }
    $suffix = ''
    if ($default) { $suffix = " [$default]" }
    while ($true) {
        $ans = Read-Host "  $label$suffix"
        if (-not $ans) { $ans = $default }
        if ($ans -or -not $Required) { return $ans }
        Write-Host "    (required)" -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "Digital TPM Agent - installer + personalizer" -ForegroundColor Cyan
Write-Host "  package : $pkg"
Write-Host "  target  : $CopilotHome"
if ($NonInteractive) { Write-Host "  mode    : non-interactive" } else { Write-Host "  mode    : interactive (press Enter to accept a [default])" }
Write-Host ""

# ---------------------------------------------------------------- 1. collect answers
# auto-detect tenant id from Azure CLI when possible
$tenantDefault = $TenantId
if (-not $tenantDefault) {
    try { $tenantDefault = (& az account show --query tenantId -o tsv 2>$null) } catch { $tenantDefault = '' }
    if ($tenantDefault) { $tenantDefault = $tenantDefault.Trim() }
}

if (-not $NonInteractive) { Write-Host "Tell me who this agent is for:" -ForegroundColor Cyan }

$AgentName      = Get-Val $AgentName      'Agent name (what it answers to, e.g. Nova)' 'Nova' -Required
$UserFullName   = Get-Val $UserFullName   'Your full name (e.g. Alex Pereira Silva)'   '' -Required

# derive name parts
$parts     = @($UserFullName -split '\s+' | Where-Object { $_ })
$firstName = if ($parts.Count -ge 1) { $parts[0] } else { $UserFullName }
$lastName  = if ($parts.Count -ge 2) { $parts[-1] } else { '' }
$nameDefault = ($firstName + ' ' + $lastName).Trim()

$UserName       = Get-Val $UserName       'Signature / display name'                   $nameDefault -Required
$UserAlias      = Get-Val $UserAlias      'Corp alias (e.g. alsilva)'                  '' -Required
$UserUpn        = Get-Val $UserUpn        'Work email / UPN (@microsoft.com)'          '' -Required
$UserTitleEn    = Get-Val $UserTitleEn    'Job title (English)'                        'Learning & Skilling Manager'
$UserTitlePt    = Get-Val $UserTitlePt    'Job title (Portuguese)'                     'Gerente de Capacitação'
$UserTitleShort = Get-Val $UserTitleShort 'Short title (for peer signatures)'          'TPM - Microsoft'
$UserTimezone   = Get-Val $UserTimezone   'Time zone'                                  'America/Sao_Paulo (GMT-03:00)'
$TenantId       = Get-Val $TenantId       'Entra tenant GUID'                          $tenantDefault -Required
$WorkdirLocal   = Get-Val $WorkdirLocal   'Local work dir (drafts live here, mandate M1)' 'C:\ghcli-working'
$Workdir        = Get-Val $Workdir        'Synced work dir (cockpit + pipelines)'      (Join-Path $env:USERPROFILE 'OneDrive - Microsoft\ghcli-working')

# derived, never asked
$userSp = ($UserUpn -replace '[@.]', '_')
$copilotHomeVal = $CopilotHome
$userProfileVal = $env:USERPROFILE

# ---------------------------------------------------------------- 2. token map
# ONLY these explicit tokens are replaced. Code placeholders like {{col}}, {{x}},
# {{Name}}, {{Body}} are intentionally absent so they are never touched.
$map = [ordered]@{
    '{{AGENT_NAME}}'       = $AgentName
    '{{USER_FULL_NAME}}'   = $UserFullName
    '{{USER_NAME}}'        = $UserName
    '{{USER_FIRSTNAME}}'   = $firstName
    '{{USER_FIRST_NAME}}'  = $firstName
    '{{USER_LASTNAME}}'    = $lastName
    '{{USER_ALIAS}}'       = $UserAlias
    '{{USER_UPN}}'         = $UserUpn
    '{{USER_SP}}'          = $userSp
    '{{USER_TITLE_EN}}'    = $UserTitleEn
    '{{USER_TITLE_PT}}'    = $UserTitlePt
    '{{USER_TITLE_SHORT}}' = $UserTitleShort
    '{{USER_TIMEZONE}}'    = $UserTimezone
    '{{TENANT_ID}}'        = $TenantId
    '{{COPILOT_HOME}}'     = $copilotHomeVal
    '{{USERPROFILE}}'      = $userProfileVal
    '{{WORKDIR}}'          = $Workdir
    '{{WORKDIR_LOCAL}}'    = $WorkdirLocal
    # neutral voice defaults so no raw {{TOKEN}} survives; rebuild later from Sent Items
    '{{OPENER_CLIENT}}'    = 'Olá,'
    '{{OPENER_PEER}}'      = 'Oi,'
    '{{OPENER_PARTNER}}'   = 'Olá,'
    '{{OPENER_EXEC}}'      = 'Prezados,'
    '{{OPENER_PEER_EN}}'   = 'Hi,'
    '{{OPENER_EXEC_EN}}'   = 'Hi team,'
    '{{CLOSER_CLIENT}}'    = 'Atenciosamente,'
    '{{CLOSER_PEER}}'      = 'Abraço,'
    '{{CLOSER_PARTNER}}'   = 'Obrigado,'
    '{{CLOSER_EXEC}}'      = 'Atenciosamente,'
    '{{CLOSER_EN}}'        = 'Best,'
}
# {{EMAIL}} is handled specially (see Convert-Text): user's UPN in code, left as a
# placeholder in docs where it may mean a third party the installer cannot know.

$codeExt = @('.py', '.ps1', '.psm1', '.js', '.cmd', '.bat', '.sh')

function ConvertTo-JsonSafe([string]$s) { return $s.Replace('\', '\\').Replace('"', '\"') }

function Convert-Text([string]$text, [string]$ext) {
    $e = $ext.ToLower()
    $isJson = ($e -eq '.json')
    foreach ($k in $map.Keys) {
        $v = $map[$k]
        if ($isJson) { $v = ConvertTo-JsonSafe $v }   # tokens live inside JSON strings
        $text = $text.Replace($k, $v)
    }
    if ($codeExt -contains $e) {
        # code: {{EMAIL}} constants (USER_UPN, self-exclusion, env defaults) = the user
        $text = $text.Replace('{{EMAIL}}', $UserUpn)
    }
    else {
        # docs/json: only the clearly-self occurrences; leave third-party senders as {{EMAIL}}
        $u = $UserUpn
        if ($isJson) { $u = ConvertTo-JsonSafe $u }
        $text = $text.Replace("<{{EMAIL}}>", "<$u>")
        $text = $text.Replace("login_hint={{EMAIL}}", "login_hint=$u")
        $text = $text.Replace("-SenderEmail '{{EMAIL}}'", "-SenderEmail '$u'")
    }
    return $text
}

$textExt = @('.md', '.txt', '.json', '.js', '.py', '.ps1', '.psm1', '.cmd', '.bat',
    '.sh', '.yml', '.yaml', '.css', '.ini', '.cfg', '.toml', '.html')

function Convert-Tree([string]$root) {
    Get-ChildItem $root -Recurse -File | ForEach-Object {
        if ($textExt -notcontains $_.Extension.ToLower()) { return }
        $orig = Read-Text $_.FullName
        $new = Convert-Text $orig $_.Extension
        if ($new -ne $orig) { Write-Text $_.FullName $new }
    }
}

# ---------------------------------------------------------------- 3. backup
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $CopilotHome "_backup_$stamp"
$backupTargets = @('agents', 'skills', 'copilot-instructions.md', 'mcp-config.json',
    'settings.json', 'permissions-config.json') |
    ForEach-Object { Join-Path $CopilotHome $_ } | Where-Object { Test-Path $_ }

if (-not (Test-Path $CopilotHome)) {
    if ($PSCmdlet.ShouldProcess($CopilotHome, 'create .copilot home')) {
        New-Item -ItemType Directory -Force -Path $CopilotHome | Out-Null
    }
}
if ($backupTargets) {
    Write-Host "Backing up existing install -> $backup" -ForegroundColor Yellow
    if ($PSCmdlet.ShouldProcess($backup, 'backup existing agents/skills/config')) {
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
        foreach ($p in $backupTargets) { Copy-Item $p -Destination $backup -Recurse -Force }
    }
}

# ---------------------------------------------------------------- 4. copy + personalize agents/skills
foreach ($sub in @('agents', 'skills')) {
    $src = Join-Path $pkg $sub
    $dst = Join-Path $CopilotHome $sub
    if (Test-Path $src) {
        if ($PSCmdlet.ShouldProcess($dst, "copy + personalize $sub")) {
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            Copy-Item (Join-Path $src '*') -Destination $dst -Recurse -Force
            Convert-Tree $dst
            $n = (Get-ChildItem $src -Recurse -File).Count
            Write-Host "  personalized $sub ($n files)" -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------------- 5. copilot-instructions.md
$ciSrc = Join-Path $pkg 'copilot-instructions.template.md'
if (Test-Path $ciSrc) {
    $ci = Read-Text $ciSrc
    # strip the "PERSONALIZE FIRST" admonition block (from that line up to the lone '>')
    $ci = [regex]::Replace($ci, "(?ms)^> \*\*.{0,6}PERSONALIZE FIRST:.*?\r?\n>\r?\n", '')
    $ci = Convert-Text $ci '.md'
    $ciDst = Join-Path $CopilotHome 'copilot-instructions.md'
    if ($PSCmdlet.ShouldProcess($ciDst, 'write personalized copilot-instructions.md')) {
        Write-Text $ciDst $ci
        Write-Host "  wrote copilot-instructions.md" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- 6. config files (write or merge)
function New-ConfigObject([string]$templateRel) {
    $p = Join-Path $pkg $templateRel
    $t = Convert-Text (Read-Text $p) '.json'
    return $t | ConvertFrom-Json
}

# mcp-config.json — add/refresh our servers, keep any the user already had
$mcpDst = Join-Path $CopilotHome 'mcp-config.json'
if ($PSCmdlet.ShouldProcess($mcpDst, 'write/merge mcp-config.json')) {
    $newMcp = New-ConfigObject 'config\mcp-config.template.json'
    if (Test-Path $mcpDst) {
        $cur = (Read-Text $mcpDst) | ConvertFrom-Json
        if (-not $cur.mcpServers) { $cur | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) -Force }
        foreach ($prop in $newMcp.mcpServers.PSObject.Properties) {
            $cur.mcpServers | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }
        Write-Text $mcpDst ($cur | ConvertTo-Json -Depth 20)
        Write-Host "  merged mcp-config.json (kept your existing servers)" -ForegroundColor Green
    }
    else {
        Write-Text $mcpDst ($newMcp | ConvertTo-Json -Depth 20)
        Write-Host "  wrote mcp-config.json" -ForegroundColor Green
    }
}

# settings.json — union allowedUrls, add missing keys, never override your scalars
$setDst = Join-Path $CopilotHome 'settings.json'
if ($PSCmdlet.ShouldProcess($setDst, 'write/merge settings.json')) {
    $newSet = New-ConfigObject 'config\settings.template.json'
    if (Test-Path $setDst) {
        $cur = (Read-Text $setDst) | ConvertFrom-Json
        $curUrls = @(); if ($cur.allowedUrls) { $curUrls = @($cur.allowedUrls) }
        $union = @($curUrls + @($newSet.allowedUrls) | Select-Object -Unique)
        $cur | Add-Member -NotePropertyName allowedUrls -NotePropertyValue $union -Force
        foreach ($prop in $newSet.PSObject.Properties) {
            if ($prop.Name -eq 'allowedUrls') { continue }
            if (-not $cur.PSObject.Properties.Name.Contains($prop.Name)) {
                $cur | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }
        }
        Write-Text $setDst ($cur | ConvertTo-Json -Depth 20)
        Write-Host "  merged settings.json (kept your preferences, added URLs)" -ForegroundColor Green
    }
    else {
        Write-Text $setDst ($newSet | ConvertTo-Json -Depth 20)
        Write-Host "  wrote settings.json" -ForegroundColor Green
    }
}

# permissions-config.json — union tool_approvals per location
$permDst = Join-Path $CopilotHome 'permissions-config.json'
if ($PSCmdlet.ShouldProcess($permDst, 'write/merge permissions-config.json')) {
    $newPerm = New-ConfigObject 'config\permissions-config.template.json'
    if (Test-Path $permDst) {
        $cur = (Read-Text $permDst) | ConvertFrom-Json
        if (-not $cur.locations) { $cur | Add-Member -NotePropertyName locations -NotePropertyValue ([pscustomobject]@{}) -Force }
        foreach ($loc in $newPerm.locations.PSObject.Properties) {
            $existing = $cur.locations.PSObject.Properties[$loc.Name]
            if (-not $existing) {
                $cur.locations | Add-Member -NotePropertyName $loc.Name -NotePropertyValue $loc.Value -Force
            }
            else {
                $seen = @{}
                $merged = @()
                foreach ($a in @($existing.Value.tool_approvals) + @($loc.Value.tool_approvals)) {
                    $key = ($a | ConvertTo-Json -Depth 20 -Compress)
                    if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $merged += $a }
                }
                $existing.Value | Add-Member -NotePropertyName tool_approvals -NotePropertyValue $merged -Force
            }
        }
        Write-Text $permDst ($cur | ConvertTo-Json -Depth 20)
        Write-Host "  merged permissions-config.json" -ForegroundColor Green
    }
    else {
        Write-Text $permDst ($newPerm | ConvertTo-Json -Depth 20)
        Write-Host "  wrote permissions-config.json" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- 7. seed workspace-scripts (never clobber your data)
$wsSrc = Join-Path $pkg 'workspace-scripts'
if (Test-Path $wsSrc) {
    if ($PSCmdlet.ShouldProcess($Workdir, 'seed workspace-scripts (copy-if-absent)')) {
        New-Item -ItemType Directory -Force -Path $Workdir | Out-Null
        # cockpit/* -> workdir root (mandate M5 runs cockpit_serve.py from here)
        $placed = 0; $skipped = 0
        Get-ChildItem (Join-Path $wsSrc 'cockpit') -File -ErrorAction SilentlyContinue | ForEach-Object {
            $dst = Join-Path $Workdir $_.Name
            if (Test-Path $dst) { $skipped++ }
            else { Write-Text $dst (Convert-Text (Read-Text $_.FullName) $_.Extension); $placed++ }
        }
        # portfolio-analytics/* -> workdir\portfolio-analytics (keeps your portfolio_config.py)
        $paDir = Join-Path $Workdir 'portfolio-analytics'
        New-Item -ItemType Directory -Force -Path $paDir | Out-Null
        Get-ChildItem (Join-Path $wsSrc 'portfolio-analytics') -File -ErrorAction SilentlyContinue | ForEach-Object {
            $dst = Join-Path $paDir $_.Name
            if (Test-Path $dst) { $skipped++ }
            else { Write-Text $dst (Convert-Text (Read-Text $_.FullName) $_.Extension); $placed++ }
        }
        Write-Host "  seeded workspace-scripts -> $Workdir ($placed new, $skipped kept)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- 8. working dirs
foreach ($d in @($WorkdirLocal, (Join-Path $WorkdirLocal 'drafts'), $Workdir)) {
    if ($PSCmdlet.ShouldProcess($d, 'create dir')) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

# ---------------------------------------------------------------- 9. optional deps
if ($InstallDeps) {
    if ($PSCmdlet.ShouldProcess('Python + Node deps', 'install')) {
        Write-Host "Installing Python/Node dependencies..." -ForegroundColor Cyan
        & python -m pip install --upgrade pandas openpyxl python-pptx python-docx beautifulsoup4 requests playwright deep-translator markitdown jsonschema
        & python -m playwright install msedge
        & npm install -g jsdom
    }
}

# ---------------------------------------------------------------- done
Write-Host ""
Write-Host "Done. '$AgentName' is installed and personalized for $UserName." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next (authenticate as yourself - the package ships no credentials):" -ForegroundColor Cyan
Write-Host "  1. az login"
Write-Host "  2. Start Copilot CLI; sign in to each MCP server on first use; run msx_login once for MSX."
if (-not $InstallDeps) {
    Write-Host "  3. Install deps if you skipped them:  ./setup.ps1 -InstallDeps  (or see SETUP.md section 6)"
}
Write-Host "  4. Verify:  python sanitization/verify_no_pii.py `"$CopilotHome`"  (add --denylist with your name/clients)"
Write-Host ""
Write-Host "Tip: ask the agent to rebuild your voice profile from your Sent Items (see PERSONALIZE.md B)." -ForegroundColor DarkGray
Write-Host "Note: a few skills reference other people's email addresses that were removed for privacy" -ForegroundColor DarkGray
Write-Host "      (they still read {{EMAIL}} in some docs). The agent will ask you for those when a skill needs one." -ForegroundColor DarkGray
