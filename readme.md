# Password Reset Tool

Requires Powershell 7

Recommended install:
````
mkdir \scripts
cd \scripts
git clone https://github.com/carbm1/Password_Reset.git
cd Password_Reset
.\student-password-reset.ps1 -Install
````

Upgrade:
````
cd \scripts\Password_Reset
git pull
````

Quit working after OS Upgrade? You must reinstall the RSAT tools.
````
cd \scripts\Password_Reset
.\student-password-reset.ps1 -Install
````

Students must be in the Students OU at the root of the domain or modify the $limitOUSearchBase variable in settings.ps1.

Copy the shortcut to the Desktop of the user who has rights to reset passwords/disable accounts.

Profit!