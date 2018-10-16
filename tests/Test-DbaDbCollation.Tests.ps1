﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Test-DbaDbCollation).Parameters.Keys
        $knownParameters = 'SqlInstance','SqlCredential','Database','ExcludeDatabase','Detailed','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {

    Context "testing collation of a single database" {
        BeforeAll {
            $server = Connect-DbaInstance -SqlInstance $script:instance1
            $db1 = "dbatoolsci_collation"
            Get-DbaDatabase -SqlInstance $server -Database $db1 | Remove-DbaDatabase -Confirm:$false
            $server.Query("CREATE DATABASE $db1")
        }
        AfterAll {
            Get-DbaDatabase -SqlInstance $server -Database $db1 | Remove-DbaDatabase -Confirm:$false
        }

        It "confirms the db is the same collation as the server" {
            $result = Test-DbaDbCollation -SqlInstance $script:instance1 -Database $db1
            $result.IsEqual
        }
    }
}