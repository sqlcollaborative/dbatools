$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'IncludeSystem', 'Login', 'Username', 'Force', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
    Context "Should error out if the database does not exist" {
        Mock Connect-SqlInstance -MockWith {
            $obj = [PSCustomObject]@{
                Databases    = [String]::Empty
                IsAccessible = $false
            }
            return $obj
        } -ModuleName dbatools
        It "Errors out when the databases does not exist and -EnableException is specified" {
            { New-DbaDbUser -SqlInstance localhost -Database 'NotAtAllReal' -Username $userName -EnableException } | Should -Throw
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolscidb_$(Get-Random)", "dbatoolscidb2_$(Get-Random)"
        $userName = "dbatoolscidb_UserWithLogin"
        $userNameWithoutLogin = "dbatoolscidb_UserWithoutLogin"

        $password = 'MyV3ry$ecur3P@ssw0rd'
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $null = New-DbaLogin -SqlInstance $script:instance3 -Login $userName -Password $securePassword -Force
        $null = New-DbaDatabase -SqlInstance $script:instance3 -Name $dbname
    }
    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $script:instance3 -Database $dbname -Confirm:$false
        $null = Remove-DbaLogin -SqlInstance $script:instance3 -Login $userName -Confirm:$false
    }
    Context "Should create the user with login" {
        It "Creates the user and get it" {
            New-DbaDbUser -SqlInstance $script:instance3 -Database $dbname[0] -Login $userName
            (Get-DbaDbUser -SqlInstance $script:instance3 -Database $dbname[0] | Where-Object Name -eq $userName).Name | Should Be $userName
        }
    }
    Context "Should create the user without login" {
        It "Creates the user and get it. Login property is empty" {
            New-DbaDbUser -SqlInstance $script:instance3 -Database $dbname[0] -User $userNameWithoutLogin
            $results = Get-DbaDbUser -SqlInstance $script:instance3 -Database $dbname[0] | Where-Object Name -eq $userNameWithoutLogin
            $results.Name | Should Be $userNameWithoutLogin
            $results.Login | Should -BeNullOrEmpty
        }
    }
}
