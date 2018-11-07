$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 4
        $commonParamCount = ([System.Management.Automation.PSCmdlet]::CommonParameters).Count + 2
        [object[]]$params = (Get-ChildItem function:\Uninstall-DbaSqlWatch).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $commonParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Testing SqlWatch uninstaller" {
        BeforeAll {
            $database = "master"
            Install-DbaSqlWatch -SqlInstance $script:instance2 -Database $database
            Uninstall-DbaSqlWatch -SqlInstance $script:instance2 -Database $database
        }

        It "Removed all tables" {
            $tableCount = (Get-DbaDbTable -SqlInstance $script:instance2 -Database $Database | Where-Object {($PSItem.Name -like "sql_perf_mon_*") -or ($PSItem.Name -like "logger_*")}).Count
            $tableCount | Should -Be 0
        }
        It "Removed all views" {
            $viewCount = (Get-DbaDbView -SqlInstance $script:instance2 -Database $Database | Where-Object {$PSItem.Name -like "vw_sql_perf_mon_*" }).Count
            $viewCount | Should -Be 0
        }
        It "Removed all stored procedures" {
            $sprocCount = (Get-DbaDbStoredProcedure -SqlInstance $script:instance2 -Database $Database | Where-Object {($PSItem.Name -like "sp_sql_perf_mon_*") -or ($PSItem.Name -like "usp_logger_*")}).Count
            $sprocCount | Should -Be 0
        }
        It "Removed all SQL Agent jobs" {
            $agentCount = (Get-DbaAgentJob -SqlInstance $script:instance2 | Where-Object {($PSItem.Name -like "SqlWatch-*") -or ($PSItem.Name -like "DBA-PERF-*")}).Count
            $agentCount | Should -Be 0
        }

    }
}