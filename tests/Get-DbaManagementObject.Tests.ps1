$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 4
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaManagementObject).Parameters.Keys
        $knownParameters = 'ComputerName','Credential','VersionNumber','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}
<#
    Integration test should appear below and are custom to the command you are writing.
    Read https://github.com/sqlcollaborative/dbatools/blob/development/contributing.md#tests
    for more guidence.
#>
Describe "Get-DbaManagementObject Integration Test" -Tag "IntegrationTests" {
    $results = Get-DbaManagementObject -ComputerName $env:COMPUTERNAME

    It "returns results" {
        $results.Count -gt 0 | Should Be $true
    }
    It "has the correct properties" {
        $result = $results[0]
        $ExpectedProps = 'ComputerName,Version,Loaded,LoadTemplate'.Split(',')
        ($result.PsObject.Properties.Name | Sort-Object) | Should Be ($ExpectedProps | Sort-Object)
    }

    $results = Get-DbaManagementObject -ComputerName $env:COMPUTERNAME -VersionNumber 10
    It "Returns the version specified" {
        $results | Should Not Be $null
    }

    It "Should return nothing if unable to connect to server" {
        $result = Get-DbaManagementObject -ComputerName 'Melton5312' -WarningAction SilentlyContinue
        $result | Should Be $null
    }
}

