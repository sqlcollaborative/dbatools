﻿function Start-DbaPowerBi {
<#        
    .SYNOPSIS
        Launches the PowerBi dashboard for dbatools
        
    .DESCRIPTION
        Launches the PowerBi dashboard for dbatools
        
    .PARAMETER Path
        The location of the pbix file. "$script:ModuleRoot\bin\pbix\dbatools.pbix" by default.
        
    .PARAMETER InputObject
        Enables piping.
        
    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
        
    .EXAMPLE
        Start-DbaPowerBi
        
        Launches PowerBi from "$script:ModuleRoot\bin\pbix\dbatools.pbix" using "C:\windows\Temp\dbatools\" (generated by Update-DbaPowerBiDataSource) as the datasource.
        
    .EXAMPLE
        Start-DbaPowerBi -Path \\nas\projects\dbatools.pbix
        
        Launches \\nas\projects\dbatools.pbix
        
        
#>
    [CmdletBinding()]
    param (
        [string]$Path = "$script:ModuleRoot\bin\pbix\dbatools.pbix",
        [parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject,
        [switch]$EnableException
    )

    process {
        if (-not (Test-Path -Path $Path)) {
            Stop-Function -Message "$Path does not exist"
            return
        }

        $association = Get-ItemProperty "Registry::HKEY_Classes_root\.pbix" -ErrorAction SilentlyContinue

        if (-not $association) {
            Stop-Function -Message ".pbix not associated with any program. Please (re)install Power BI"
            return
        }

        if ($Path -match "Program Files") {
            $newpath = "$script:localapp\dbatools.pbix"
            #if ((Test-Path -Path $newpath)) { # Would be nice if we could tell if it needed to be replaced or not
            #I suppose we could use dbatools versioning and wintemp?
            Copy-Item -Path $Path -Destination $newpath -Force -ErrorAction SilentlyContinue
            $Path = $newpath
        }

        try {
            Invoke-Item -Path $path
        }
        catch {
            Stop-Function -Message "Failure" -ErrorRecord $_
            return
        }
    }
}