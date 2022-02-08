#Requires -Version 7.0

<#
	Password Reset Script for Student Management Accounts group members.

	2021-8-18 Craig Millsap

	* Currently this script does not verify you have access to the OU prior to atttempting the password reset.

	If you're running on an Azure AD joined machine you'll need to rename the settings-sample.ps1 file to settings.ps1 and define the closest server to you.
	You should have SSO turned on with your Azure AD Connect so it should automatically authenticate you.

#>

Param(
    [Parameter(Mandatory=$false)][switch]$Install #Install all the dependencies and create the shortcut on the desktop for this user.
)

if (Test-Path .\settings.ps1) {
	. .\settings.ps1

	#make the script talk to a specific server. Needed for AzureAD connected machines.
	if ($server) {
		$PSDefaultParameterValues = @{"*-AD*:Server"="$server"}
	}

	#Limit the search to a specific OU.
	if ($limitOUSearchBase) {
		$ou = $limitOUSearchBase
	} else {
		$ou = "ou=Students,$((Get-AdDomain).DistinguishedName)"
	}
}

if ($Install) {

	#must run as admin.
	if (-Not $(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		write-host "Must run as administrator!"
		write-host -NoNewline 'Press any key to continue...'
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
		exit(1)
	}

	$currentWU = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" | Select-Object -ExpandProperty UseWUServer
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0
	Restart-Service wuauserv
	Get-WindowsCapability -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -Online | Add-WindowsCapability –Online
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value $currentWU
	Restart-Service wuauserv

	exit
}

#Load VisualBasic so we can have prompts that look decent.
[void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

#We need to load the ActiveDirectory Module. If this fails then show error.
try {
	Import-Module ActiveDirectory
} catch {
	[Microsoft.VisualBasic.Interaction]::MsgBox("Missing the Active Directory Modules. Please contact your admin.",0,"Error")
	exit(1)
}

#Query for student last name.
$studentquery = [Microsoft.VisualBasic.Interaction]::InputBox("Search for students last name:`n`nExamples:`nAda would match Adams`n*ams would match Adams", "Search", '')

#If nothing entered full stop.
if (($null -eq $studentquery) -or ($studentquery -eq "") -or ($studentquery -eq '*')) {
	[Microsoft.VisualBasic.Interaction]::MsgBox("You didn't search for anything.",0,"Try again.")
	exit(1)
}

#Query AD
try {
	$students = Get-AdUser -Filter "(SurName -like ""$($studentquery)*"") -and (Enabled -eq 'True')" -SearchBase $ou -Properties EmailAddress,HomePhone,physicalDeliveryOfficeName
} catch {
	[Microsoft.VisualBasic.Interaction]::MsgBox("Failed to query Active Directory for user.",0,"Try again.")
	exit(1)
}

if ($students.Count -le 0) {
	[Microsoft.VisualBasic.Interaction]::MsgBox("No students were found. Please try again.",0,"NO RESULTS")
	exit
}

#lets transform the results into something more readable for the end user.
$students = $students | Select-Object -Property @{Name='First Name';Expression={ $PSItem.GivenName }},
	@{Name='Last Name';Expression={ $PSItem.SurName }},
	@{Name='EmailAddress';Expression={ $PSItem.EmailAddress }},
	@{Name='Grade';Expression={ $PSItem.HomePhone }},
	@{Name='School';Expression={ $PSItem.physicalDeliveryOfficeName }},ObjectGUID | Sort-Object -Property "Last Name","First Name"


$selecteduser = $students | Out-GridView -PassThru -Title "Please select a student to reset their password."

if ($selecteduser.Count -gt 1) {
	$response = [Microsoft.VisualBasic.Interaction]::MsgBox("This tool is designed to only reset one student at a time.",5,"Error Multiple Student Selected.")
	
	if ($response -eq 'Retry') {
		$selecteduser = $students | Out-GridView -PassThru -Title "Please select a student to reset their password."
	} else {
		exit(1)
	}

	if ($selecteduser.Count -gt 1) {
		[Microsoft.VisualBasic.Interaction]::MsgBox("This tool is designed to only reset one student at a time.",0,"Error Multiple Student Selected.")
		exit(1)
	}
}

if ($selecteduser.ObjectGuid) {
	$selecteduser
	$user = Get-Aduser -Identity $selecteduser.ObjectGuid
} else {
	$selecteduser
	[Microsoft.VisualBasic.Interaction]::MsgBox("No account selected.",0,"Password Reset Failed")
	exit 1
}

if ($disableAccountsInstead) {

	try {
		Disable-ADAccount -Identity $user
		[Microsoft.VisualBasic.Interaction]::MsgBox("$($user.GivenName) $($user.Surname)`'s account has been disabled. The account should be reactivated in the next few minutes. You should recieve an email with their new system generated password.",0,"Done")
		exit 0
	} catch {
		[Microsoft.VisualBasic.Interaction]::MsgBox("Something went wrong disabling the account. Most likely you don't have permissions to disable this student.",0,"Disable Account Failed")
		exit(1)
	}

} else {
	$randomword = Get-Random -InputObject 'Way','Law','Child','Queen','Guest','News','Oven','Power','Lady','Heart','Mom','Cell','Story','Tale','Sir','Poet','Cheek','Two','Mood','Disk','Ear','Basis','Tooth','Week','Mud','Idea','Poem','Debt','Tea','Pizza','Owner','Menu','Loss','Event','Topic','Chest','Uncle','Hall','Piano','Youth','Meat','User','Night','Honey','Gate','Media','Bird'
	$randomspecial = Get-Random -InputObject '!','#','$','.','?','@'
	[string]$randomnum = Get-Random -Minimum 10000 -Maximum 99999
	$password = "$($randomword)$($randomspecial)$($randomnum)"

	if ($password.Length -gt 8) { $password = $password.Substring(0,8) }

	#write-host "$password"

	try {
		Set-AdAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString "$password" -AsPlainText -force)
		if ($requirepasswordchange) {
			Set-ADUser -Identity $user -ChangePasswordAtLogon $true
		}
	} catch {
		[Microsoft.VisualBasic.Interaction]::MsgBox("Something went wrong. Most likely you don't have permissions to reset this student.",0,"Password Reset Failed")
		exit(1)
	}

	[Microsoft.VisualBasic.Interaction]::MsgBox("$($user.GivenName) $($user.Surname)`'s password has been reset to:`n$password`n`nPlease have them change their password immediately by following the Change My Password link on their start page.",0,"Done")
}

exit