$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'MessageID', 'Language', 'EnableException'
        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance1
        $server2 = Connect-DbaInstance -SqlInstance $script:instance2

        $results = New-DbaCustomError -SqlInstance $server -MessageID 70000 -Severity 1 -MessageText "test_70000"
        $results = New-DbaCustomError -SqlInstance $server, $server2 -MessageID 70001 -Severity 1 -MessageText "test_70001"
        $results = New-DbaCustomError -SqlInstance $server, $server2 -MessageID 70002 -Severity 1 -MessageText "test_70002"
        $results = New-DbaCustomError -SqlInstance $server -MessageID 70003 -Severity 1 -MessageText "test_70003" -Language "English"
        $results = New-DbaCustomError -SqlInstance $server -MessageID 70005 -Severity 5 -MessageText "test_70005" -Language "English"

        # add other languages available now that the english message is added
        $languages = $server.Query("SELECT alias FROM sys.syslanguages WHERE alias NOT LIKE '%English%'")

        foreach ($lang in $languages) {
            $languageName = $lang.alias
            $results = New-DbaCustomError -SqlInstance $server -MessageID 70003 -Severity 1 -MessageText "test_70003_$languageName" -Language "$languageName"
            $results2 = New-DbaCustomError -SqlInstance $server -MessageID 70005 -Severity 5 -MessageText "test_70005_$languageName" -Language "$languageName"
        }

        $results = New-DbaCustomError -SqlInstance $server -MessageID 70004 -Severity 1 -MessageText "test_70004" -Language "English"
    }
    AfterAll {
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70000) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70000, @lang = 'all'; END")
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70001) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70001, @lang = 'all'; END")
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70002) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70002, @lang = 'all'; END")
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70003) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70003, @lang = 'all'; END")
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70004) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70004, @lang = 'all'; END")
        $server.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70005) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70005, @lang = 'all'; END")
        $server2.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70001) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70001, @lang = 'all'; END")
        $server2.Query("IF EXISTS (SELECT 1 FROM master.sys.messages WHERE message_id = 70002) BEGIN EXEC msdb.dbo.sp_dropmessage @msgnum = 70002, @lang = 'all'; END")
    }

    Context "Validate params" {

        It "Message ID" {
            { $results = Remove-DbaCustomError -SqlInstance $server -MessageID 1 -Language English } | Should -Throw
            { $results = Remove-DbaCustomError -SqlInstance $server -MessageID 2147483648 -Language English } | Should -Throw

            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70000
            $results.Count | Should -Be 1
        }

        It "Language" {
            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70003 -Language "InvalidLanguage"
            $results | Should -BeNullOrEmpty

            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70003 -Language "French"
            $results.Count | Should -Be 1

            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70003 -Language "All"
            $results.Count | Should -Be 1 # SMO does a cascade delete of all messages by related ID in this scenario, so the resulting count is 1.

            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70004 -Language "English"
            $results.Count | Should -Be 1

            $results = Remove-DbaCustomError -SqlInstance $server -MessageID 70005
            $results.Count | Should -Be 1
        }
    }

    Context "Supports multiple server inputs" {

        It "Preconnected servers" {
            $results = ([DbaInstanceParameter[]]$server, $server2 | Remove-DbaCustomError -MessageID 70001)
            $results.Count | Should -Be 2
        }

        It "Multiple servers via -SqlInstance" {
            $results = Remove-DbaCustomError -SqlInstance $script:instance1, $script:instance2 -MessageID 70002
            $results.Count | Should -Be 2
        }
    }

    Context "Simulate the sp_altermessage" {

        It "Use the existing commands to simulate sp_altermessage" {
            $results = New-DbaCustomError -SqlInstance $server -MessageID 70000 -Severity 1 -MessageText "test_70000"
            $results.IsLogged | Should -Be $false

            $original = $server.UserDefinedMessages | Where-Object ID -eq 70000

            $messageID = $original.ID
            $severity = $original.Severity
            $text = $original.Text
            $language = $original.Language

            $removed = Remove-DbaCustomError -SqlInstance $server -MessageID 70000

            $altered = New-DbaCustomError -SqlInstance $server -MessageID $messageID -Severity $severity -MessageText $text -Language $language -WithLog
            $altered.IsLogged | Should -Be $true
            $altered.ID | Should -Be 70000
        }
    }
}