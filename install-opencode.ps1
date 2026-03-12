[CmdletBinding()]
param(
    [bool]$InstallMissingPrerequisites = $true,
    [bool]$InstallGit = $true,
    [bool]$InstallNode = $true,
    [bool]$InstallBun = $true,
    [bool]$InstallOhMyOpenAgent = $true,

    [switch]$NonInteractive,

    [AllowNull()]
    [ValidateSet('no', 'yes', 'max20')]
    [string]$Claude,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$OpenAI,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$Gemini,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$Copilot,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$OpenCodeZen,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$ZaiCodingPlan,

    [AllowNull()]
    [ValidateSet('no', 'yes')]
    [string]$OpenCodeGo
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Test-IsInteractiveSession {
    if ($NonInteractive) {
        return $false
    }

    if ($env:CI -eq 'true' -or $env:CI -eq '1') {
        return $false
    }

    return [Environment]::UserInteractive
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$AllowedValues,
        [string]$DefaultValue = 'no'
    )

    $allowedDisplay = $AllowedValues -join '/'

    while ($true) {
        $rawValue = Read-Host "$Prompt [$allowedDisplay] (default: $DefaultValue)"
        if ([string]::IsNullOrWhiteSpace($rawValue)) {
            return $DefaultValue
        }

        $value = $rawValue.Trim().ToLowerInvariant()
        if ($AllowedValues -contains $value) {
            return $value
        }

        Write-Info "Please enter one of: $allowedDisplay"
    }
}

function Resolve-ProviderValue {
    param(
        [string]$Name,
        [AllowNull()][string]$Value,
        [string[]]$AllowedValues,
        [bool]$Interactive,
        [string]$DefaultValue = 'no'
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    if (-not $Interactive) {
        return $DefaultValue
    }

    return Read-Choice -Prompt "Configure $Name provider" -AllowedValues $AllowedValues -DefaultValue $DefaultValue
}

function Resolve-ProviderConfiguration {
    param([bool]$Interactive)

    Write-Step 'Resolving provider configuration'
    if ($Interactive) {
        Write-Info 'Provider flags that were not supplied will be asked interactively. Press Enter to accept the default of no.'
    } else {
        Write-Info 'Running in non-interactive mode. Omitted provider flags default to no.'
    }

    return [ordered]@{
        Claude = Resolve-ProviderValue -Name 'Claude' -Value $Claude -AllowedValues @('no', 'yes', 'max20') -Interactive $Interactive
        OpenAI = Resolve-ProviderValue -Name 'OpenAI' -Value $OpenAI -AllowedValues @('no', 'yes') -Interactive $Interactive
        Gemini = Resolve-ProviderValue -Name 'Gemini' -Value $Gemini -AllowedValues @('no', 'yes') -Interactive $Interactive
        Copilot = Resolve-ProviderValue -Name 'Copilot' -Value $Copilot -AllowedValues @('no', 'yes') -Interactive $Interactive
        OpenCodeZen = Resolve-ProviderValue -Name 'OpenCode Zen' -Value $OpenCodeZen -AllowedValues @('no', 'yes') -Interactive $Interactive
        ZaiCodingPlan = Resolve-ProviderValue -Name 'Z.ai Coding Plan' -Value $ZaiCodingPlan -AllowedValues @('no', 'yes') -Interactive $Interactive
        OpenCodeGo = Resolve-ProviderValue -Name 'OpenCode Go' -Value $OpenCodeGo -AllowedValues @('no', 'yes') -Interactive $Interactive
    }
}

function Assert-Winget {
    if (-not (Test-Command 'winget')) {
        throw "winget is required to auto-install prerequisites. Install App Installer from Microsoft Store or rerun with -InstallMissingPrerequisites:`$false."
    }
}

function Install-WithWinget {
    param(
        [string]$Id,
        [string]$DisplayName
    )

    Assert-Winget
    Write-Step "Installing $DisplayName with winget"
    & winget install --id $Id --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed while installing $DisplayName ($Id)."
    }
}

function Assert-CommandAvailable {
    param(
        [string]$Name,
        [string]$DisplayName
    )

    Refresh-Path
    if (-not (Test-Command $Name)) {
        throw "$DisplayName was installed, but '$Name' is still not available in the current shell. Open a new terminal and rerun the script."
    }
}

function Ensure-Command {
    param(
        [string]$Name,
        [bool]$ShouldInstall,
        [string]$WingetId,
        [string]$DisplayName
    )

    if (Test-Command $Name) {
        Write-Success "$DisplayName is already installed"
        return
    }

    if (-not $ShouldInstall) {
        throw "$DisplayName is missing. Install it first or enable automatic installation."
    }

    if (-not $InstallMissingPrerequisites) {
        throw "$DisplayName is missing and automatic prerequisite installation is disabled."
    }

    Install-WithWinget -Id $WingetId -DisplayName $DisplayName
    Assert-CommandAvailable -Name $Name -DisplayName $DisplayName
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $currentEntries = @($env:Path -split ';' | Where-Object { $_ })
    $persistedEntries = @("$machinePath;$userPath" -split ';' | Where-Object { $_ })
    $mergedEntries = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $currentEntries + $persistedEntries) {
        if (-not $mergedEntries.Contains($entry)) {
            [void]$mergedEntries.Add($entry)
        }
    }

    $env:Path = $mergedEntries -join ';'
}

function Install-OpenCode {
    if (Test-Command 'opencode') {
        Write-Success "OpenCode is already installed: $(opencode --version)"
        return
    }

    Write-Step 'Installing OpenCode globally with npm'
    & npm install -g opencode-ai
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install opencode-ai globally with npm.'
    }
    Assert-CommandAvailable -Name 'opencode' -DisplayName 'OpenCode'
}

function Install-OhMyOpenAgent {
    param([string[]]$Flags)

    $runner = if (Test-Command 'bunx') { 'bunx' } elseif (Test-Command 'npx') { 'npx' } else { $null }
    if (-not $runner) {
        throw 'Neither bunx nor npx is available, so the oh-my-openagent installer cannot run.'
    }

    Write-Step "Running oh-my-openagent installer with $runner"
    $arguments = @(
        'oh-my-opencode',
        'install',
        '--no-tui'
    ) + $Flags

    & $runner @arguments
    if ($LASTEXITCODE -ne 0) {
        throw 'oh-my-openagent installer failed.'
    }
}

function Invoke-Installer {
    Write-Host 'MyOpenAgentInstaller - Windows OpenCode bootstrap' -ForegroundColor Yellow

    Write-Step 'Checking prerequisites'
    Ensure-Command -Name 'git' -ShouldInstall $InstallGit -WingetId 'Git.Git' -DisplayName 'Git'
    Refresh-Path
    Ensure-Command -Name 'node' -ShouldInstall $InstallNode -WingetId 'OpenJS.NodeJS.LTS' -DisplayName 'Node.js LTS'
    Refresh-Path

    if (-not (Test-Command 'npm')) {
        throw 'npm is still unavailable after Node.js installation. Open a new terminal and rerun the script.'
    }

    if ($InstallBun) {
        if (Test-Command 'bun') {
            Write-Success 'Bun is already installed'
        } elseif ($InstallMissingPrerequisites) {
            Install-WithWinget -Id 'Oven-sh.Bun' -DisplayName 'Bun'
            Assert-CommandAvailable -Name 'bun' -DisplayName 'Bun'
        } else {
            Write-Info 'Bun is not installed. The script will fall back to npx for oh-my-openagent.'
        }
    } else {
        Write-Info 'Skipping Bun installation by request'
    }

    Write-Step 'Installing OpenCode'
    Install-OpenCode

    Write-Step 'Verifying OpenCode'
    if (-not (Test-Command 'opencode')) {
        throw 'opencode is not available on PATH after installation. Open a new terminal and try again.'
    }

    $opencodeVersion = opencode --version
    Write-Success "OpenCode installed: $opencodeVersion"

    if ($InstallOhMyOpenAgent) {
        $resolvedProviders = Resolve-ProviderConfiguration -Interactive (Test-IsInteractiveSession)
        $omoFlags = @(
            "--claude=$($resolvedProviders.Claude)",
            "--openai=$($resolvedProviders.OpenAI)",
            "--gemini=$($resolvedProviders.Gemini)",
            "--copilot=$($resolvedProviders.Copilot)",
            "--opencode-zen=$($resolvedProviders.OpenCodeZen)",
            "--zai-coding-plan=$($resolvedProviders.ZaiCodingPlan)",
            "--opencode-go=$($resolvedProviders.OpenCodeGo)"
        )

        Install-OhMyOpenAgent -Flags $omoFlags
    } else {
        Write-Info 'Skipping oh-my-openagent installation by request'
    }

    Write-Step 'Final verification'
    Write-Host "OpenCode version: $(opencode --version)" -ForegroundColor Green

    if ($InstallOhMyOpenAgent) {
        $configDir = Join-Path $env:USERPROFILE '.config\opencode'
        $jsonPath = Join-Path $configDir 'opencode.json'
        $jsoncPath = Join-Path $configDir 'opencode.jsonc'

        if (Test-Path $jsonPath) {
            Write-Info "Detected OpenCode config: $jsonPath"
        } elseif (Test-Path $jsoncPath) {
            Write-Info "Detected OpenCode config: $jsoncPath"
        } else {
            Write-Info 'OpenCode config was not found in the default user config directory yet.'
        }
    }

    Write-Host ''
    Write-Success 'Bootstrap complete.'
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host '  1. Open a new terminal if PATH changes were not picked up.'
    Write-Host '  2. Run: opencode'
    Write-Host '  3. Complete provider authentication inside OpenCode if needed.'
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Installer
}
