### Version 1.0 - Refactored by @blacktyg3r

###########################################################################################
############    Fork of: https://github.com/ChrisTitusTech/powershell-profile  ############
###########################################################################################

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for Profile Updates
function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        $url = "https://raw.githubusercontent.com/blacktyger/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Refreshing active shell instance.." -ForegroundColor Magenta
	    & $PROFILE
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}

function Update-PowerShell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Refreshing active shell instance.." -ForegroundColor Magenta
	    & $PROFILE
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell


# Add/Remove $PATHs
Function setpath {
    param (
        [string]$add,
        [string]$rm,
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'User'
    )
    # To handle white spaces in paths
    $env:add_p = "$add"
    $env:rm_p = "$rm"
    $regexPaths = @()
    
    if ($PSBoundParameters.Keys -contains 'add') {
        $regexPaths += [regex]::Escape($env:add_p)
    }

    if ($PSBoundParameters.Keys -contains 'rm') {
        $regexPaths += [regex]::Escape($env:rm_p)
    }
    
    $arrPath = [System.Environment]::GetEnvironmentVariable('PATH', $Scope) -split ';'
    foreach ($path in $regexPaths) {
        $arrPath = $arrPath | Where-Object { $_ -notMatch "^$path\\?" }
    }
    $value = ($arrPath + $env:add_p) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $value, $Scope)
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists sublime_text) { 'sublime_text' }
          elseif (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

# Alias for PyCharm
Set-Alias -Name pyc -Value pycharm64 -Option AllScope -Scope Global -Force

# Edit this file
function Edit-Profile {
    vim $PROFILE
}
function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# Open WinUtil
function winutil {
	iwr -useb https://christitus.com/win | iex
}

# System Utilities - will run the command with elevated rights in new window
function sudo {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function reload-profile {
    & $profile
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    
    $FilePath = $args[0]
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }
    
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

### Quality of Life Aliases

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }

function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function g { __zoxide_z github }

function gcl { git clone "$args" }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
    Parameter          = $PSStyle.Foreground.Magenta
    Selection          = $PSStyle.Background.Black
    InLinePrediction   = $PSStyle.Foreground.BrightYellow + $PSStyle.Background.BrightBlack
    }
}
Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock


# Initialize starship prompt and run fastfetch 
function Get-Prompt{
    starship init powershell | Invoke-Expression
    fastfetch -l small --logo-padding-top 5
}

## Final Line to set prompt
Get-Prompt
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
Set-Alias -Name c -Value clear -Option AllScope -Scope Global -Force
Set-Alias -Name tg -Value telegram -Option AllScope -Scope Global -Force

# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-Profile - Checks for profile updates from a remote repository and updates if necessary.

Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.

Edit-Profile - Opens the current user's profile for editing using the configured editor.

setpath -add or -rm <PATH> - edit user's $PATH 

touch <file> - Creates a new empty file.

ff <name> - Finds files recursively with the specified name.

Get-PubIP - Retrieves the public IP address of the machine.

winutil - Runs the WinUtil script from Chris Titus Tech.

uptime - Displays the system uptime.

reload-profile - Reloads the current user's PowerShell profile.

unzip <file> - Extracts a zip file to the current directory.

hb <file> - Uploads the specified file's content to a hastebin-like service and returns the URL.

grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

df - Displays information about volumes.

sed <file> <find> <replace> - Replaces text in a file.

which <name> - Shows the path of the command.

export <name> <value> - Sets an environment variable.

pkill <name> - Kills processes by name.

pgrep <name> - Lists processes by name.

head <path> [n] - Displays the first n lines of a file (default 10).

tail <path> [n] - Displays the last n lines of a file (default 10).

nf <name> - Creates a new file with the specified name.

mkcd <dir> - Creates and changes to a new directory.

docs - Changes the current directory to the user's Documents folder.

dtop - Changes the current directory to the user's Desktop folder.

ep - Opens the profile for editing.

k9 <name> - Kills a process by name.

la - Lists all files in the current directory with detailed formatting.

ll - Lists all files, including hidden, in the current directory with detailed formatting.

c - clear

gs - Shortcut for 'git status'.

ga - Shortcut for 'git add .'.

gc <message> - Shortcut for 'git commit -m'.

gp - Shortcut for 'git push'.

g - Changes to the GitHub directory.

gcom <message> - Adds all changes and commits with the specified message.

lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

sysinfo - Displays detailed system information.

flushdns - Clears the DNS cache.

cpy <text> - Copies the specified text to the clipboard.

pst - Retrieves text from the clipboard.

Use 'Show-Help' to display this help message.
"@
}
Write-Host "Use 'Show-Help' to display help"
