# Need this variable as long as we support PS v2
$ModuleBasePath = Split-Path $MyInvocation.MyCommand.Path -Parent

# Store error records generated by stderr output when invoking an executable
# This can be accessed from the user's session by executing:
# PS> $m = Get-Module DbaTools
# PS> & $m Get-Variable invokeErrors -ValueOnly
$invokeErrors = New-Object System.Collections.ArrayList 256

# General Utility Functions

function Invoke-NullCoalescing {
    $result = $null
    foreach($arg in $args) {
        if ($arg -is [ScriptBlock]) {
            $result = & $arg
        }
        else {
            $result = $arg
        }
        if ($result) { break }
    }
    $result
}

Set-Alias ?? Invoke-NullCoalescing -Force

function Invoke-Utf8ConsoleCommand([ScriptBlock]$cmd) {
    $currentEncoding = [Console]::OutputEncoding
    $errorCount = $global:Error.Count
    try {
        # A native executable that writes to stderr AND has its stderr redirected will generate non-terminating
        # error records if the user has set $ErrorActionPreference to Stop. Override that value in this scope.
        $ErrorActionPreference = 'Continue'
        if ($currentEncoding.IsSingleByte) {
            [Console]::OutputEncoding = [Text.Encoding]::UTF8
        }
        & $cmd
    }
    finally {
        if ($currentEncoding.IsSingleByte) {
            [Console]::OutputEncoding = $currentEncoding
        }

        # Clear out stderr output that was added to the $Error collection, putting those errors in a module variable
        if ($global:Error.Count -gt $errorCount) {
            $numNewErrors = $global:Error.Count - $errorCount
            $invokeErrors.InsertRange(0, $global:Error.GetRange(0, $numNewErrors))
            if ($invokeErrors.Count -gt 256) {
                $invokeErrors.RemoveRange(256, ($invokeErrors.Count - 256))
            }
            $global:Error.RemoveRange(0, $numNewErrors)
        }
    }
}

<#
.SYNOPSIS
    Configures your PowerShell profile (startup) script to import the DbaTools
    module when PowerShell starts.
.DESCRIPTION
    Checks if your PowerShell profile script is not already importing DbaTools
    and if not, adds a command to import the DbaTools module. This will cause
    PowerShell to load DbaTools whenever PowerShell starts.
.PARAMETER AllHosts
    By default, this command modifies the CurrentUserCurrentHost profile
    script.  By specifying the AllHosts switch, the command updates the
    CurrentUserAllHosts profile.
.PARAMETER Force
    Do not check if the specified profile script is already importing
    DbaTools. Just add Import-Module DbaTools command.
.PARAMETER StartSshAgent
    Also add `Start-SshAgent -Quiet` to the specified profile script.
.EXAMPLE
    PS C:\> Add-DbaToolsToProfile
    Updates your profile script for the current PowerShell host to import the
    DbaTools module when the current PowerShell host starts.
.EXAMPLE
    PS C:\> Add-DbaToolsToProfile -AllHost
    Updates your profile script for all PowerShell hosts to import the DbaTools
    module whenever any PowerShell host starts.
.INPUTS
    None.
.OUTPUTS
    None.
#>
function Add-DbaToolsToProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]
        $AllHosts,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $StartSshAgent,

        [Parameter(ValueFromRemainingArguments)]
        [psobject[]]
        $TestParams
    )

    $underTest = $false

    $profilePath = if ($AllHosts) { $PROFILE.CurrentUserAllHosts } else { $PROFILE.CurrentUserCurrentHost }

    # Under test, we override some variables using $args as a backdoor.
    if (($TestParams.Count -gt 0) -and ($TestParams[0] -is [string])) {
        $profilePath = [string]$TestParams[0]
        $underTest = $true
        if ($TestParams.Count -gt 1) {
            $ModuleBasePath = [string]$TestParams[1]
        }
    }

    if (!$profilePath) { $profilePath = $PROFILE }

    if (!$Force) {
        # Search the user's profiles to see if any are using DbaTools already, there is an extra search
        # ($profilePath) taking place to accomodate the Pester tests.
        $importedInProfile = Test-DbaToolsImportedInScript $profilePath
        if (!$importedInProfile -and !$underTest) {
            $importedInProfile = Test-DbaToolsImportedInScript $PROFILE
        }
        if (!$importedInProfile -and !$underTest) {
            $importedInProfile = Test-DbaToolsImportedInScript $PROFILE.CurrentUserCurrentHost
        }
        if (!$importedInProfile -and !$underTest) {
            $importedInProfile = Test-DbaToolsImportedInScript $PROFILE.CurrentUserAllHosts
        }
        if (!$importedInProfile -and !$underTest) {
            $importedInProfile = Test-DbaToolsImportedInScript $PROFILE.AllUsersCurrentHost
        }
        if (!$importedInProfile -and !$underTest) {
            $importedInProfile = Test-DbaToolsImportedInScript $PROFILE.AllUsersAllHosts
        }

        if ($importedInProfile) {
            Write-Warning "Skipping add of DbaTools import to file '$profilePath'."
            Write-Warning "DbaTools appears to already be imported in one of your profile scripts."
            Write-Warning "If you want to force the add, use the -Force parameter."
            return
        }
    }

    if (!$profilePath) {
        Write-Warning "Skipping add of DbaTools import to profile; no profile found."
        Write-Verbose "`$profilePath          = '$profilePath'"
        Write-Verbose "`$PROFILE              = '$PROFILE'"
        Write-Verbose "CurrentUserCurrentHost = '$($PROFILE.CurrentUserCurrentHost)'"
        Write-Verbose "CurrentUserAllHosts    = '$($PROFILE.CurrentUserAllHosts)'"
        Write-Verbose "AllUsersCurrentHost    = '$($PROFILE.AllUsersCurrentHost)'"
        Write-Verbose "AllUsersAllHosts       = '$($PROFILE.AllUsersAllHosts)'"
        return
    }

    # If the profile script exists and is signed, then we should not modify it
    if (Test-Path -LiteralPath $profilePath) {
        $sig = Get-AuthenticodeSignature $profilePath
        if ($null -ne $sig.SignerCertificate) {
            Write-Warning "Skipping add of DbaTools import to profile; '$profilePath' appears to be signed."
            Write-Warning "Add the command 'Import-Module DbaTools' to your profile and resign it."
            return
        }
    }

    # Check if the location of this module file is in the PSModulePath
    if (Test-InPSModulePath $ModuleBasePath) {
        $profileContent = "`nImport-Module DbaTools"
    }
    else {
        $profileContent = "`nImport-Module '$ModuleBasePath\DbaTools.psd1'"
    }

    # Make sure the PowerShell profile directory exists
    $profileDir = Split-Path $profilePath -Parent
    if (!(Test-Path -LiteralPath $profileDir)) {
        if ($PSCmdlet.ShouldProcess($profileDir, "Create current user PowerShell profile directory")) {
            New-Item $profileDir -ItemType Directory -Force -Verbose:$VerbosePreference > $null
        }
    }

    if ($PSCmdlet.ShouldProcess($profilePath, "Add 'Import-Module DbaTools' to profile")) {
        Add-Content -LiteralPath $profilePath -Value $profileContent -Encoding UTF8
    }
    if ($StartSshAgent -and $PSCmdlet.ShouldProcess($profilePath, "Add 'Start-SshAgent -Quiet' to profile")) {
        Add-Content -LiteralPath $profilePath -Value 'Start-SshAgent -Quiet' -Encoding UTF8
    }
}

<#
.SYNOPSIS
    Gets the file encoding of the specified file.
.DESCRIPTION
    Gets the file encoding of the specified file.
.PARAMETER Path
    Path to the file to check.  The file must exist.
.EXAMPLE
    PS C:\> Get-FileEncoding $profile
    Get's the file encoding of the profile file.
.INPUTS
    None.
.OUTPUTS
    [System.String]
.NOTES
    Adapted from http://www.west-wind.com/Weblog/posts/197245.aspx
#>
function Get-FileEncoding($Path) {
    $bytes = [byte[]](Get-Content $Path -Encoding byte -ReadCount 4 -TotalCount 4)

    if (!$bytes) { return 'utf8' }

    switch -regex ('{0:x2}{1:x2}{2:x2}{3:x2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3]) {
        '^efbbbf'   { return 'utf8' }
        '^2b2f76'   { return 'utf7' }
        '^fffe'     { return 'unicode' }
        '^feff'     { return 'bigendianunicode' }
        '^0000feff' { return 'utf32' }
        default     { return 'ascii' }
    }
}

<#
.SYNOPSIS
    Gets a StringComparison enum value appropriate for comparing paths on the OS platform.
.DESCRIPTION
    Gets a StringComparison enum value appropriate for comparing paths on the OS platform.
.EXAMPLE
    PS C:\> $pathStringComparison = Get-PathStringComparison
.INPUTS
    None
.OUTPUTS
    [System.StringComparison]
#>
function Get-PathStringComparison {
    # File system paths are case-sensitive on Linux and case-insensitive on Windows and macOS
    if (($PSVersionTable.PSVersion.Major -ge 6) -and $IsLinux) {
        [System.StringComparison]::Ordinal
    }
    else {
        [System.StringComparison]::OrdinalIgnoreCase
    }
}

function Get-PSModulePath {
    $modulePaths = $Env:PSModulePath -split ';'
    $modulePaths
}

function Test-InPSModulePath {
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $Path
    )

    $modulePaths = Get-PSModulePath
    if (!$modulePaths) { return $false }

    $pathStringComparison = Get-PathStringComparison
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $inModulePath = @($modulePaths | Where-Object { $Path.StartsWith($_.TrimEnd([System.IO.Path]::DirectorySeparatorChar), $pathStringComparison) }).Count -gt 0

    if ($inModulePath -and ('src' -eq (Split-Path $Path -Leaf))) {
        Write-Warning 'DbaTools repository structure is incompatible with %PSModulePath%.'
        Write-Warning 'Importing with absolute path instead.'
        return $false
    }

    $inModulePath
}

function Test-DbaToolsImportedInScript {
    param (
        [Parameter(Position=0)]
        [string]
        $Path
    )

    if (!$Path -or !(Test-Path -LiteralPath $Path)) {
        return $false
    }

    $match = (@(Get-Content $Path -ErrorAction SilentlyContinue) -match 'DbaTools').Count -gt 0
    if ($match) { Write-Verbose "DbaTools found in '$Path'" }
    $match
}

function dbg($Message, [Diagnostics.Stopwatch]$Stopwatch) {
    if ($Stopwatch) {
        Write-Verbose ('{0:00000}:{1}' -f $Stopwatch.ElapsedMilliseconds,$Message) -Verbose # -ForegroundColor Yellow
    }
}
