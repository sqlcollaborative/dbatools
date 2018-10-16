﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbCertificate).Parameters.Keys
        $knownParameters = 'SqlInstance','SqlCredential','Database','ExcludeDatabase','Certificate','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Can get a database certificate" {
        BeforeAll {
            if (-not (Get-DbaDbMasterKey -SqlInstance $script:instance1 -Database master)) {
                $masterkey = New-DbaDbMasterKey -SqlInstance $script:instance1 -Database master -Password $(ConvertTo-SecureString -String "GoodPass1234!" -AsPlainText -Force) -Confirm:$false
            }

            $tempdbmasterkey = New-DbaDbMasterKey -SqlInstance $script:instance1 -Database tempdb -Password $(ConvertTo-SecureString -String "GoodPass1234!" -AsPlainText -Force) -Confirm:$false
            $certificateName1 = "Cert_$(Get-random)"
            $certificateName2 = "Cert_$(Get-random)"
            $cert1 = New-DbaDbCertificate -SqlInstance $script:instance1 -Name $certificateName1 -Confirm:$false
            $cert2 = New-DbaDbCertificate -SqlInstance $script:instance1 -Name $certificateName2 -Database "tempdb" -Confirm:$false
        }
        AfterAll {
            $null = $cert1 | Remove-DbaDbCertificate -Confirm:$false
            $null = $cert2 | Remove-DbaDbCertificate -Confirm:$false
            if ($tempdbmasterkey) { $tempdbmasterkey | Remove-DbaDbMasterKey -Confirm:$false }
            if ($masterKey) { $masterkey | Remove-DbaDbMasterKey -Confirm:$false }
        }

        $cert = Get-DbaDbCertificate -SqlInstance $script:instance1 -Certificate $certificateName1
        It "returns database certificate created in default, master database" {
            "$($cert.Database)" -match 'master' | Should Be $true
        }

        $cert = Get-DbaDbCertificate -SqlInstance $script:instance1 -Database tempdb
        It "returns database certificate created in tempdb database, looked up by certificate name" {
            "$($cert.Name)" -match $certificateName2 | Should Be $true
        }

        $cert = Get-DbaDbCertificate -SqlInstance $script:instance1 -ExcludeDatabase master
        It "returns database certificates excluding those in the master database" {
            "$($cert.Database)" -notmatch 'master' | Should Be $true
        }

    }
}