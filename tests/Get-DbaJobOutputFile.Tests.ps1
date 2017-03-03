#Thank you Warren http://ramblingcookiemonster.github.io/Testing-DSC-with-Pester-and-AppVeyor/

if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}
$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}



$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.', '.')
Import-Module $PSScriptRoot\..\functions\$sut -Force
. $PSScriptRoot\..\Internal\Connect-SQLServer.ps1 -Force
Import-Module PSScriptAnalyzer
## Added PSAvoidUsingPlainTextForPassword as credential is an object and therefore fails. We can ignore any rules here under special circumstances agreed by admins :-)
$Rules = (Get-ScriptAnalyzerRule).Where{$_.RuleName -notin ('PSAvoidUsingPlainTextForPassword') }
$Name = $sut.Split('.')[0]

   Describe 'Script Analyzer Tests' -Tag @('ScriptAnalyzer'){ 
            Context 'Testing $sut for Standard Processing' {
                foreach ($rule in $rules) { 
                    $i = $rules.IndexOf($rule)
                    It "passes the PSScriptAnalyzer Rule number $i - $rule  " {
                        (Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\functions\$sut" -IncludeRule $rule.RuleName ).Count | Should Be 0 
                    }
                }
            }
        } 
   ## needs some proper tests for the function here
    Describe "$Name Tests" -Tag @('Command'){
        Context "Input Validation" { 
          It 'SqlServer parameter is empty' { 
            { Get-DbaJobOutputFile -SqlServer ''  -WarningAction Stop 3> $null } | Should Throw 
         } 
          It 'SqlServer parameter host cannot be found' { 
            Mock Connect-SqlServer { throw System.Data.SqlClient.SqlException } 
            { Get-DbaJobOutputFile  -SqlServer 'ABC' -WarningAction Stop 3> $null } | Should Throw 
         } 
		} ## End Context Input
    }
    
    