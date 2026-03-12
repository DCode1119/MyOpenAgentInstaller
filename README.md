# MyOpenAgentInstaller

Windows-first bootstrap installer for `opencode` and the Oh My OpenCode plugin package published as `oh-my-opencode`.

This repository is meant for a basic Windows machine that does not already have the full toolchain set up. The installer can:

- install missing prerequisites with `winget`
- install `opencode`
- run the Oh My OpenCode installer in non-interactive mode
- verify that `opencode` is callable afterward

## What it installs

By default, the PowerShell installer will:

1. ensure `git` exists
2. ensure `node`/`npm` exists
3. optionally ensure `bun` exists
4. install `opencode` globally with `npm`
5. run `bunx oh-my-opencode install` when `bun` is available, otherwise `npx oh-my-opencode install`

Note on naming: the GitHub repository is `oh-my-openagent`, but the installable package and CLI command are still `oh-my-opencode`.

The script uses conservative defaults for provider flags:

- `Claude`: `no`
- `OpenAI`: `no`
- `Gemini`: `no`
- `Copilot`: `no`
- `OpenCode Zen`: `no`
- `Z.ai Coding Plan`: `no`
- `OpenCode Go`: `no`

Change those when you know which subscriptions you want to wire in.

## Requirements

- Windows 10 or later
- PowerShell 5.1+ or PowerShell 7+
- `winget` available if you want the script to auto-install missing prerequisites
- Administrator PowerShell recommended when installing prerequisites globally

## Quick start

From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-opencode.ps1
```

Or use the wrapper:

```bat
install-opencode.cmd
```

## Examples

Install with Claude Max 20x and ChatGPT Plus configured in the OmO installer:

```powershell
.\install-opencode.ps1 -Claude max20 -OpenAI yes
```

Install with GitHub Copilot fallback only:

```powershell
.\install-opencode.ps1 -Copilot yes
```

Skip automatic prerequisite installation and fail fast if something is missing:

```powershell
.\install-opencode.ps1 -InstallMissingPrerequisites:$false
```

## Parameters

### Installer behavior

- `-InstallMissingPrerequisites` (default: `$true`)
- `-InstallGit` (default: `$true`)
- `-InstallNode` (default: `$true`)
- `-InstallBun` (default: `$true`)
- `-InstallOhMyOpenAgent` (default: `$true`) - installs the `oh-my-opencode` package from the `oh-my-openagent` project

### Provider flags

- `-Claude` = `no` | `yes` | `max20`
- `-OpenAI` = `no` | `yes`
- `-Gemini` = `no` | `yes`
- `-Copilot` = `no` | `yes`
- `-OpenCodeZen` = `no` | `yes`
- `-ZaiCodingPlan` = `no` | `yes`
- `-OpenCodeGo` = `no` | `yes`

## What the script does not do

- it does not complete browser auth flows for providers
- it does not overwrite an existing OpenCode config blindly
- it does not require `bun` to run the plugin installer because `npx` is used as a fallback

After the install completes, open a new terminal and run:

```powershell
opencode
```

If you want to continue setup manually, these references are useful:

- OpenCode download: `https://opencode.ai/download`
- OpenCode Windows guidance: `https://opencode.ai/docs/windows-wsl/`
- Oh My OpenAgent installation guide: `https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md`
