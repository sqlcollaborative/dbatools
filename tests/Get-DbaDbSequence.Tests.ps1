$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'Name', 'Schema', 'InputObject', 'EnableException'
        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {

    BeforeAll {
        $random = Get-Random
        $instance1 = Connect-DbaInstance -SqlInstance $script:instance1
        $null = Get-DbaProcess -SqlInstance $instance1 | Where-Object Program -match dbatools | Stop-DbaProcess -Confirm:$false
        $newDbName = "dbatoolsci_newdb_$random"
        $newDb = New-DbaDatabase -SqlInstance $instance1 -Name $newDbName

        $sequence = New-DbaDbSequence -SqlInstance $instance1 -Database $newDbName -Name "Sequence1_$random" -Schema "Schema_$random"
    }

    AfterAll {
        $null = $newDb | Remove-DbaDatabase -Confirm:$false
    }

    Context "commands work as expected" {

        It "validates required Database param" {
            $sequence = Get-DbaDbSequence -SqlInstance $instance1 -Name SequenceTest -ErrorVariable error
            $sequence | Should -BeNullOrEmpty
            $error | Should -Match "Database is required when SqlInstance is specified"
        }

        It "finds a sequence" {
            $sequence = Get-DbaDbSequence -SqlInstance $instance1 -Database $newDbName -Name "Sequence1_$random" -Schema "Schema_$random"
            $sequence.Name | Should -Be "Sequence1_$random"
            $sequence.Schema | Should -Be "Schema_$random"
            $sequence.Parent.Name | Should -Be $newDbName
        }

        It "supports piping databases" {
            $sequence = Get-DbaDatabase -SqlInstance $instance1 -Database $newDbName | Get-DbaDbSequence -Name "Sequence1_$random" -Schema "Schema_$random"
            $sequence.Name | Should -Be "Sequence1_$random"
            $sequence.Schema | Should -Be "Schema_$random"
            $sequence.Parent.Name | Should -Be $newDbName
        }
    }
}