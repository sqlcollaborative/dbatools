$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tags "UnitTests" {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'Credential', 'Auto', 'Configuration', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    $resultsNew = New-DbaFirewallRule -SqlInstance $script:instance2 -Auto -Confirm:$false
    $resultsGet = Get-DbaFirewallRule -SqlInstance $script:instance2
    $instanceName = ([DbaInstanceParameter]$script:instance2).InstanceName

    It "New creates two firewall rules" {
        $resultsNew.Count | Should -Be 2
    }

    It "New creates first firewall rule for SQL Server instance" {
        $resultsNew[0].DisplayName | Should -Be "SQL Server instance $instanceName"
        $resultsNew[0].Successful | Should -Be $true
        $resultsNew[0].Warning | Should -Be $null
        $resultsNew[0].Error | Should -Be $null
        $resultsNew[0].Exception | Should -Be $null
    }

    It "New creates second firewall rule for SQL Server Browser" {
        $resultsNew[1].DisplayName | Should -Be "SQL Server Browser"
        $resultsNew[1].Successful | Should -Be $true
        $resultsNew[1].Warning | Should -Be $null
        $resultsNew[1].Error | Should -Be $null
        $resultsNew[1].Exception | Should -Be $null
    }

    It "Get returns two firewall rules" {
        $resultsGet.Count | Should -Be 2
    }

    # More tests will be added later
}