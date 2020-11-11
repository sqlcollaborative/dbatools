function Install-DbaMultiTool {
    <#
    .SYNOPSIS
        Installs or updates the DBA MultiTool stored procedures.

    .DESCRIPTION
        Downloads, extracts and installs the DBA MultiTool stored procedures.

        DBA MultiTool links:
        https://dba-multitool.org
        https://github.com/LowlyDBA/dba-multitool/

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Database
        Specifies the database to install DBA MultiTool stored procedures into.

    .PARAMETER Branch
        Specifies an alternate branch of the DBA MultiTool to install.
        Allowed values:
            master (default)
            development

    .PARAMETER LocalFile
        Specifies the path to a local file to install DBA MultiTool from. This *should* be the zip file as distributed by the maintainers.
        If this parameter is not specified, the latest version will be downloaded and installed from https://github.com/LowlyDBA/dba-multitool/.

    .PARAMETER Force
        If this switch is enabled, the DBA MultiTool will be downloaded from the internet even if previously cached.

    .PARAMETER Confirm
        Prompts to confirm actions.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Community, DbaMultiTool
        Author: John McCall (@lowlydba), https://lowlydba.com/

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

        https://dba-multitool.org

    .LINK
        https://dbatools.io/Install-DbaMultiTool

    .EXAMPLE
        PS C:\> Install-DbaMultiTool -SqlInstance server1 -Database master

        Logs into server1 with Windows authentication and then installs the DBA MultiTool in the master database.

    .EXAMPLE
        PS C:\> Install-DbaMultiTool -SqlInstance server1\instance1 -Database DBA

        Logs into server1\instance1 with Windows authentication and then installs the DBA MultiTool in the DBA database.

    .EXAMPLE
        PS C:\> Install-DbaMultiTool -SqlInstance server1\instance1 -Database master -SqlCredential $cred

        Logs into server1\instance1 with SQL authentication and then installs the DBA MultiTool in the master database.

    .EXAMPLE
        PS C:\> Install-DbaMultiTool -SqlInstance sql2016\standardrtm, sql2016\sqlexpress, sql2014

        Logs into sql2016\standardrtm, sql2016\sqlexpress and sql2014 with Windows authentication and then installs the DBA MultiTool in the master database.

    .EXAMPLE
        PS C:\> $Servers = "sql2016\standardrtm", "sql2016\sqlexpress", "sql2014"
        PS C:\> $Servers | Install-DbaMultiTool

        Logs into sql2016\standardrtm, sql2016\sqlexpress and sql2014 with Windows authentication and then installs the DBA MultiTool in the master database.

    .EXAMPLE
        PS C:\> Install-DbaMultiTool -SqlInstance sql2016 -Branch development

        Installs the development branch version of the DBA MultiTool in the master database on sql2016 instance.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [ValidateSet('master', 'development')]
        [string]$Branch = "master",
        [object]$Database = "master",
        [string]$LocalFile,
        [switch]$Force,
        [switch]$EnableException
    )
    begin {
        if ($Force) { $ConfirmPreference = 'none' }

        $DbatoolsData = Get-DbatoolsConfigValue -FullName "Path.DbatoolsData"

        if (-not $DbatoolsData) {
            $DbatoolsData = [System.IO.Path]::GetTempPath()
        }

        $Url = "https://github.com/LowlyDBA/dba-multitool/archive/$Branch.zip"
        $Temp = [System.IO.Path]::GetTempPath()
        $ZipFile = Join-Path -Path $Temp -ChildPath "DBA-MultiTool-$Branch.zip"
        $ZipFolder = Join-Path -Path $Temp -ChildPath "DBA-MultiTool-$Branch"
        $LocalCachedCopy = Join-Path -Path $DbatoolsData -ChildPath "DBA-MultiTool-$Branch"
        $MinimumVersion = 11

        if ($Force -or -not(Test-Path -Path $LocalCachedCopy -PathType Container) -or $LocalFile) {
            # Force was passed, or we don't have a local copy, or $LocalFile was passed
            if (Test-Path $ZipFile) {
                if ($PSCmdlet.ShouldProcess($ZipFile, "File found, dropping $ZipFile")) {
                    Remove-Item -Path $ZipFile -ErrorAction SilentlyContinue
                }
            }

            if ($LocalFile) {
                if (-not (Test-Path $LocalFile)) {
                    if ($PSCmdlet.ShouldProcess($LocalFile, "File does not exists, returning to prompt")) {
                        Stop-Function -Message "$LocalFile doesn't exist."
                        return
                    }
                }
                if (Test-Path $LocalFile -PathType Container) {
                    if ($PSCmdlet.ShouldProcess($LocalFile, "File is not a zip file, returning to prompt")) {
                        Stop-Function -Message "$LocalFile should be a zip file."
                        return
                    }
                }
                if (Test-Windows -NoWarn) {
                    if ($PSCmdlet.ShouldProcess($LocalFile, "Checking if Windows system, unblocking file")) {
                        Unblock-File $LocalFile -ErrorAction SilentlyContinue
                    }
                }
                if ($PSCmdlet.ShouldProcess($LocalFile, "Extracting archive to $Temp path")) {
                    Expand-Archive -Path $LocalFile -DestinationPath $Temp -Force
                }
            } else {
                Write-Message -Level Verbose -Message "Downloading and unzipping the DBA MultiTool zip file."
                if ($PSCmdlet.ShouldProcess($Url, "Downloading zip file")) {
                    try {
                        try {
                            Invoke-TlsWebRequest $Url -OutFile $ZipFile -ErrorAction Stop -UseBasicParsing
                        } catch {
                            # Try with default proxy and usersettings
                            (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                            Invoke-TlsWebRequest $Url -OutFile $ZipFile -ErrorAction Stop -UseBasicParsing
                        }

                        # Unblock if there's a block
                        if (Test-Windows -NoWarn) {
                            Unblock-File $ZipFile -ErrorAction SilentlyContinue
                        }

                        Expand-Archive -Path $ZipFile -DestinationPath $Temp -Force
                        Remove-Item -Path $ZipFile
                    } catch {
                        Stop-Function -Message "Couldn't download the DBA MultiTool. Download and install manually from $Url." -ErrorRecord $_
                        return
                    }
                }
            }

            ## Copy it into local area
            if ($PSCmdlet.ShouldProcess("LocalCachedCopy", "Copying extracted files to the local module cache")) {
                if (Test-Path -Path $LocalCachedCopy -PathType Container) {
                    Remove-Item -Path (Join-Path $LocalCachedCopy '*') -Recurse -ErrorAction SilentlyContinue
                } else {
                    $null = New-Item -Path $LocalCachedCopy -ItemType Container
                }
                Copy-Item -Path "$ZipFolder\sp_*.sql" -Destination $LocalCachedCopy
            }
        }
    }

    process {
        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            if ($PSCmdlet.ShouldProcess($instance, "Connecting to $instance")) {
                try {
                    $Server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
                } catch {
                    Stop-Function -Message "Error occurred while establishing connection to $instance." -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
                }
            }
            if ($PSCmdlet.ShouldProcess($database, "Installing DBA MultiTool procedures in $database on $instance")) {
                Write-Message -Level Verbose -Message "Starting installing/updating the DBA MultiTool stored procedures in $database on $instance."
                $AllProcedures_Query = "SELECT name FROM sys.procedures WHERE is_ms_shipped = 0;"
                $AllProcedures = ($Server.Query($AllProcedures_Query, $Database)).Name

                # Install/Update each stored procedure
                $sqlScripts = Get-ChildItem $LocalCachedCopy -Filter "sp_*.sql"
                foreach ($script in $sqlScripts) {
                    $ScriptName = $script.Name
                    $ScriptError = $false

                    $BaseRes = [PSCustomObject]@{
                        ComputerName = $Server.ComputerName
                        InstanceName = $Server.ServiceName
                        SqlInstance  = $Server.DomainInstanceName
                        Database     = $Database
                        Name         = $script.BaseName
                        Status       = $null
                    }
                    if ($Server.VersionMajor -lt $MinimumVersion) {
                        Write-Message -Level Warning -Message "$instance found to be below SQL Server 2012, skipping $ScriptName."
                        $BaseRes.Status = 'Skipped'
                        $BaseRes
                        continue
                    }
                    if ($Pscmdlet.ShouldProcess($instance, "installing/updating $ScriptName in $database")) {
                        try {
                            Invoke-DbaQuery -SqlInstance $Server -Database $Database -File $script.FullName -EnableException -Verbose:$false
                        } catch {
                            Write-Message -Level Warning -Message "Could not execute at least one portion of $ScriptName in $Database on $instance." -ErrorRecord $_
                            $ScriptError = $true
                        }

                        if ($ScriptError) {
                            $BaseRes.Status = 'Error'
                        } elseif ($script.BaseName -in $AllProcedures) {
                            $BaseRes.Status = 'Updated'
                        } else {
                            $BaseRes.Status = 'Installed'
                        }
                        $BaseRes
                    }
                }
            }
            Write-Message -Level Verbose -Message "Finished installing/updating DBA MultiTool stored procedures in $database on $instance."
        }
    }
}