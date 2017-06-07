function Get-DbaServerInfo {
	<#
		.SYNOPSIS
			Gets various bits of information from a given server.

		.DESCRIPTION
			Gets information on the server, either returning one large object or subset based on parameters.

		.PARAMETER ComputerName
			The SQL Server (or server in general) that you're connecting to.

		.PARAMETER Credential
			Credential object used to connect to the server as a different user

		.PARAMETER Silent
			Use this switch to disable any kind of verbose messages.

		.NOTES
			Tags: ServerInfo
			Original Author: Shawn Melton (@wsmelton | http://blog.wsmelton.info)

			Website: https: //dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https: //opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Get-DbaServerInfo

		.EXAMPLE
			Get-DbaServerInfo 
			Example of how to use this cmdlet

		.EXAMPLE
			Get-DbaServerInfo 
			Another example of how to use this cmdlet
	#>
	[CmdletBinding()]
	param (
		[Parameter(Position= 0, Mandatory= $true, ValueFromPipeline= $true)]
		[DbaInstanceParameter[]]$ComputerName,
		[PSCredential][System.Management.Automation.CredentialAttribute()]
		$Credential,
		[switch]$Silent
	)

	process {
		foreach ($instance in $SqlInstance) {
			Write-Message -Level Verbose -Message "Attempting to connect to $instance"
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
			}
			catch {
				Stop-Function -Message "Can't connect to $instance or access denied. Skipping." -Continue
			}

			
		} #end foreach instance
	} #end process
} #end function