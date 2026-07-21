<#
.SYNOPSIS
  Compatibility shim. The installer is now setup.ps1, which both copies the logic
  AND personalizes it (no manual file editing). This forwards to it.

.NOTES
  Prefer running the personalizing installer directly:
      ./setup.ps1                 # interactive — it asks you everything
      ./setup.ps1 -WhatIf         # preview only
  Or let the CLI agent do it for you — see INSTALL.md.
#>

# no param()/CmdletBinding here on purpose: forward ALL args (incl. -WhatIf,
# -NonInteractive, -AgentName ...) straight through to setup.ps1 via $args.

Write-Host "install.ps1 now forwards to setup.ps1 (copies + personalizes, no editing)." -ForegroundColor Yellow
Write-Host "For the guided, agent-driven install instead, see INSTALL.md." -ForegroundColor DarkGray
Write-Host ""

$setup = Join-Path $PSScriptRoot 'setup.ps1'
if (-not (Test-Path $setup)) { throw "setup.ps1 not found next to install.ps1." }

# pass through any args the caller provided (e.g. -WhatIf, -NonInteractive, -AgentName ...)
& $setup @args
