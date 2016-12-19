Function Update-SqlLoginName
{
<#
.SYNOPSIS 
Verb-DbaNoun migrates server triggers from one SQL Server to another. 

.DESCRIPTION
By default, all triggers are copied. The -Triggers parameter is autopopulated for command-line completion and can be used to copy only specific triggers.

If the trigger already exists on the destination, it will be skipped unless -Force is used. 

.PARAMETER Source
Source SQL Server.You must have sysadmin access and server version must be SQL Server version 2000 or greater.

.PARAMETER Destination
Destination Sql Server. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

.PARAMETER SqlInstance 
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter. 

Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. 	
To connect as a different Windows user, run PowerShell as that user.

.NOTES 
Original Author: Mitchell Hamann (@SirCaptainMitch)

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Update-SqlLoginName

.EXAMPLE   
Update-SqlLoginName 

.EXAMPLE   
Update-SqlLoginName 

.EXAMPLE   
Update-SqlLoginName 

#>
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	param (
		[parameter(Mandatory = $true)]
		[object]$SqlInstance,
		[System.Management.Automation.PSCredential]$SqlInstanceCredential,
		[parameter(Mandatory = $true)]
		[String]$UserName, 
		[parameter(Mandatory = $true)]
		[String]$NewUserName
	)
	DynamicParam { if ($SqlInstance) { return (Get-ParamSqlLogins -SqlServer $SqlInstance -SqlCredential $SqlInstanceCredential) } }
	
	BEGIN
	{	
		$sourceserver = Connect-SqlServer -SqlServer $SqlInstance -SqlCredential $SqlInstanceCredential					
		$Databases = $sourceserver.Databases
		$currentUser = $sourceserver.Logins[$UserName]
		
	}
	PROCESS
	{
		Write-Output "Changing Login name from $userName to $NewUserName"
		$currentUser.rename($NewUserName)
		
		foreach ($db in $currentUser.EnumDatabaseMappings())
		{
			$db = $databases[$db.DBName]

			Write-Output "Starting update for $($db.Name)" 

			try { 
								
				Write-Output "Changing database user: $username to $NewUserName"
				$db.Users[$userName].Rename($newUserName)
				
			} catch {

				Write-Warning "Rolling back update to login: $userName"
				$currentUser.rename($userName) 

				Write-Warning "The update to User: $userName failed on $($db.Name) Please check the log."				
				Write-Exception $_ 
			}
		}
	}
	
	END
	{		
		If ($Pscmdlet.ShouldProcess("console", "Showing finished message")) { Write-Output "Login update completed." }
	}
}