$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance', 'Identity', 'SqlCredential', 'Credential', 'Path', 'ExcludePassword', 'Append', 'InputObject', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $plaintext = "ReallyT3rrible!"
        $password = ConvertTo-SecureString $plaintext -AsPlainText -Force
        $null = New-DbaCredential -SqlInstance $script:instance2 -Name dbatoolsci_CaptainAcred -Identity dbatoolsci_CaptainAcred -Password $password
        $null = New-DbaCredential -SqlInstance $script:instance2 -Identity dbatoolsci_Hulk -Password $password
    }
    AfterAll {
        try {
            (Get-DbaCredential -SqlInstance $script:instance2 -Identity dbatoolsci_CaptainAcred, dbatoolsci_Hulk -ErrorAction Stop -WarningAction SilentlyContinue).Drop()
        } catch { }
        $ExportedCredential = Get-ChildItem "$env:USERPROFILE\Documents" | Where-Object { $_.Name -match '\d{14}-credential.sql|dbatoolsci_credential.sql|temp-credential.sql' }
        $null = Remove-Item -Path $($ExportedCredential.FullName) -ErrorAction SilentlyContinue
    }

    Context "Should export all credentails" {
        $null = Export-DbaCredential -SqlInstance $script:instance2
        $Export = Get-ChildItem "$env:USERPROFILE\Documents" | Where-Object { $_.name -match '\d{14}-credential' }
        $results = Get-Content -Path $Export.FullName

        It "Should have information" {
            $results | Should Not Be Null
        }
        It "Should have all users" {
            $results | Should Match 'CaptainACred|Hulk'
        }
        It "Should have the password" {
            $results | Should Match 'ReallyT3rrible!'
        }
    }

    Context "Should export a specific credential" {
        $path = "$env:USERPROFILE\Documents\dbatoolsci_credential.sql"
        $null = Export-DbaCredential -SqlInstance $script:instance2 -Identity 'dbatoolsci_CaptainAcred' -Path $path
        $results = Get-Content -Path $path

        It "Should have information" {
            $results | Should Not Be Null
        }

        It "Should only have one credential" {
            $results | Should Match 'CaptainAcred'
        }

        It "Should have the password" {
            $results | Should Match 'ReallyT3rrible!'
        }
    }

    Context "Should export a specific credential and append it to exisiting export" {
        $path = "$env:USERPROFILE\Documents\dbatoolsci_credential.sql"
        $null = Export-DbaCredential -SqlInstance $script:instance2 -Identity 'dbatoolsci_Hulk' -Path $path -Append
        $results = Get-Content -Path $path

        It "Should have information" {
            $results | Should Not Be Null
        }

        It "Should have multiple credential" {
            $results | Should Match 'Hulk|CaptainA'
        }

        It "Should have the password" {
            $results | Should Match 'ReallyT3rrible!'
        }
    }

    Context "Should export a specific credential excluding the password" {
        $path = "$env:USERPROFILE\Documents\temp-credential.sql"
        $null = Export-DbaCredential -SqlInstance $script:instance2 -Identity 'dbatoolsci_Hulk' -Path $path -ExcludePassword
        $results = Get-Content -Path $path

        It "Should have information" {
            $results | Should Not Be $null
        }

        It "Should not have the password" {
            $results | Should Not Match 'ReallyT3rrible!'
        }
    }
}