$server = "dc1.gentry.local"

#Limit this machine to only searching a specific OU for students. Comment out if you want to search all of ou=students,dc=domain,dc=local
$limitOUSearchBase = "ou=GMS,ou=Students,dc=gentry,dc=local"

#Change to true to force a Local AD Password Change only. This does not effect Azure AD or Google. Which is why I think its useless.
$requirepasswordchange = $False

#This should now be the default action now that the watchdog service is working in Automated Students 
$disableAccountsInstead = $True