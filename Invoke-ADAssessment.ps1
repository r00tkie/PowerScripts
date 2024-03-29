<#.  
SCRIPTNAME: Invoke-AdAssessment.ps1
Author: Spyros Manglis (ev53gw)
Last Updated: 31/08/2020


This script is designed for a single AD forest and is not designed to capture all data for a multiple domain forest.
Note that if this script is used for a single domain in a multi-domain AD forest, not all elements may be captured.

This script requires the following:
 * PowerShell 5.0 (minimum)
 * Windows 10/2016 or Later
 * Active Directory PowerShell Module
 * Group Policy PowerShell Module
#> 

Param
 (
    $Domain,
    $ReportDir = '.',

    [int]$UserLogonAge = '180',
    [int]$UserPasswordAge = '180'
 )
 
IF (!(Test-Path $ReportDir)) {new-item -type Directory -path $ReportDir}  
$TimeVal = get-date -uformat "%Y-%m-%d-%H-%M" 
$LogFile = $ReportDir + "\Invoke-AdAssessment-LogFile-$TimeVal.log"
Start-Transcript $LogFile


function Get-NameForGUID{
# From http://blog.wobl.it/2016/04/active-directory-guid-to-friendly-name-using-just-powershell/
	[CmdletBinding()]
	Param(
		[guid]$guid,
        [string]$ForestDNSName
	)
	Begin{
        IF (!$ForestDNSName)
        { $ForestDNSName = (Get-ADForest $ForestDNSName).Name }

        IF ($ForestDNSName -notlike "*=*")
         { $ForestDNSNameDN = “DC=$($ForestDNSName.replace(“.”, “,DC=”))” }

            $ExtendedRightGUIDs = "LDAP://cn=Extended-Rights,cn=configuration,$ForestDNSNameDN"
		    $PropertyGUIDs = "LDAP://cn=schema,cn=configuration,$ForestDNSNameDN"
	}
	Process{
		If($guid -eq "00000000-0000-0000-0000-000000000000"){
			Return "All"
		}Else{
			$rightsGuid = $guid
			$property = "cn"
			$SearchAdsi = ([ADSISEARCHER]"(rightsGuid=$rightsGuid)")
			$SearchAdsi.SearchRoot = $ExtendedRightGUIDs
			$SearchAdsi.SearchScope = "OneLevel"
			$SearchAdsiRes = $SearchAdsi.FindOne()
			If($SearchAdsiRes){
				Return $SearchAdsiRes.Properties[$property]
			}Else{
				$SchemaGuid = $guid
				$SchemaByteString = "\" + ((([guid]$SchemaGuid).ToByteArray() | %{$_.ToString("x2")}) -Join "\")
				$property = "ldapDisplayName"
				$SearchAdsi = ([ADSISEARCHER]"(schemaIDGUID=$SchemaByteString)")
				$SearchAdsi.SearchRoot = $PropertyGUIDs
				$SearchAdsi.SearchScope = "OneLevel"
				$SearchAdsiRes = $SearchAdsi.FindOne()
				If($SearchAdsiRes){
					Return $SearchAdsiRes.Properties[$property]
				}Else{
					Write-Host -f Yellow $guid
					Return $guid.ToString()
				}
			}
		}
	}
}


Write-Host "Initializing script Invoke-AdAssessment..." -Fore Cyan
$ScriptTimer = [System.Diagnostics.Stopwatch]::StartNew()

IF (!$Domain)
 { $Domain = (Get-ADDomain).DNSRoot } 

#Import-Module ActiveDirectory
#Import-Module GroupPolicy



## Get AD Forest & Domain Info
$Domain = (Get-ADDomain).DNSRoot #JUICE
$ADForestInfo = Get-ADForest
$ForestDNSName = $ADForestInfo.Name
$ADDomainInfo = Get-ADDomain $Domain
$ADDomainNetBIOSName = $ADDomainInfo.NetBIOSName
$ADDomainName = $ADDomainInfo.DNSRoot
$DomainDN = $ADDomainInfo.DistinguishedName
$DomainDC = $ADDomainInfo.PDCEmulator 


Write-Host "Starting AD Discovery & Checks..." -Fore Cyan
Write-Host ""
IF (($ADForestInfo.Domains).count -gt 1)
 { Write-Host "There are $(($ADForestInfo.Domains).count) domains in the AD Forest. Only the currently selected domain ($ADDomainName) is being analyzed. `n" -Fore Cyan }
ELSE
 { Write-Host "The AD Forest is a single domain forest and is now being analyzed... `n" -Fore Cyan }
Write-Host ""



## Identify AD FFL/DFL
## Get AD Forest & Domain Info
$ADFFL = (Get-ADForest).ForestMode
$ADDFL = (Get-ADDomain $Domain).DomainMode
Write-Host "The AD Forest Functional Level is $ADFFL `n" -Fore Cyan
Write-Host "The AD Domain Functional Level ($Domain) is $ADFFL `n" -Fore Cyan



## Get Domain Controllers 
$DomainDCs = Get-ADDomainController -filter * -Server $DomainDC
Write-Host "$ADDomainName AD Forest Domain Controllers and OS Version:  `n" -Fore Cyan
$DomainDCs | Select HostName,OperatingSystem | Format-Table -AutoSize
$ForestDomainDomainDCsFile = $ReportDir + "\ADChecks-DomainDCs-$Domain-$TimeVal.csv"
$DomainDCs | Sort OperatingSystem | Export-CSV $ForestDomainDomainDCsFile -NoTypeInformation  



## TMB Lifetime & AD Backups
$ADRootDSE = get-adrootdse  -Server $DomainDC
$ADConfigurationNamingContext = $ADRootDSE.configurationNamingContext  
$ForestRootDN = $ADRootDSE.rootDomainNamingContext
$ForestNCs = $ADRootDSE.NamingContexts
$DomainControllerSiteNameDN = "CN=Sites,$ADConfigurationNamingContext"
$TombstoneObjectInfo = Get-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$ADConfigurationNamingContext" `
-Partition "$ADConfigurationNamingContext" -Properties * 
[int]$TombstoneLifetime = $TombstoneObjectInfo.tombstoneLifetime
IF ($TombstoneLifetime -eq 0) { $TombstoneLifetime = 60 } 
Write-Host "The AD Forest Tombstone lifetime is set to $TombstoneLifetime days." -Fore Cyan
Write-Host " `n"



## AD Backups
[string[]]$Partitions = (Get-ADRootDSE -Server $DomainDC).namingContexts
$contextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain
$context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext($contextType,$ADDomainName)
$domainController = [System.DirectoryServices.ActiveDirectory.DomainController]::findOne($context)
Write-Host "Determining last supported backup of AD partitions... `n" -ForegroundColor Cyan
ForEach($partition in $partitions)
{
   $domainControllerMetadata = $domainController.GetReplicationMetadata($partition)
   $dsaSignature = $domainControllerMetadata.Item(“dsaSignature”)
   Write-Host "$partition was backed up $($dsaSignature.LastOriginatingChangeTime.DateTime)" 
}



## Trusts
$ADTrusts = Get-ADTrust -Filter * -Server $DomainDC
Write-Host "$Domain Active Directory Trusts: `n" -Fore Cyan
$ADTrusts | Select Source,Target,Direction,IntraForest,SelectiveAuth,SIDFilteringForestAware,SIDFilteringQuarantined | Format-Table -AutoSize
$ADTrustFile = $ReportDir + "\ADChecks-DomainTrustReport-$Domain-$TimeVal.csv"
$ADTrusts | Export-CSV $ADTrustFile -NoTypeInformation  



## Get Domain User Information (Time Consuming)
## I've put a limit on 500 objects
$ADLimitedProperties = @("Name","Enabled","SAMAccountname","DisplayName","Enabled","LastLogonDate","PasswordLastSet","PasswordNeverExpires","PasswordNotRequired","PasswordExpired","SmartcardLogonRequired","AccountExpirationDate","AdminCount","Created","Modified","LastBadPasswordAttempt","badpwdcount","mail","CanonicalName","DistinguishedName","ServicePrincipalName","SIDHistory","PrimaryGroupID","UserAccountControl")

## Get users with password last changes more than a year ago
$Date = (Get-Date).AddYears(-1).ToFileTime()
[array]$DomainUsersWithOldPassword = Get-ADUser -LDAPFilter "(pwdlastset<=$Date)" -Property $ADLimitedProperties -Server $DomainDC
[array]$DomainUsers = Get-ADUser -Filter * -ResultSetSize 200 -Property $ADLimitedProperties -Server $DomainDC
[array]$DomainEnabledUsers = $DomainUsers | Where {$_.Enabled -eq $True }
[array]$DomainEnabledInactiveUsers = $DomainEnabledUsers | Where { ($_.LastLogonDate -le $LastLoggedOnDate) -AND ($_.PasswordLastSet -le $PasswordStaleDate) }

[array]$DomainUsersWithReversibleEncryptionPasswordArray = $DomainUsers | Where { $_.UserAccountControl -band 0x0080 } 
[array]$DomainUserPasswordNotRequiredArray = $DomainUsers | Where {$_.PasswordNotRequired -eq $True}
[array]$DomainUserPasswordNeverExpiresArray = $DomainUsers | Where {$_.PasswordNeverExpires -eq $True}
[array]$DomainKerberosDESUsersArray = $DomainUsers | Where { $_.UserAccountControl -band 0x200000 }
[array]$DomainUserDoesNotRequirePreAuthArray = $DomainUsers | Where {$_.DoesNotRequirePreAuth -eq $True}
[array]$DomainUsersWithSIDHistoryArray = $DomainUsers | Where {$_.SIDHistory -like "*"}

Write-Output " "
$DomainUserReport =
@"
$Domain Domain User Report:

Total Users: $($DomainUsers.Count)
Enabled Users: $($DomainEnabledUsers.Count) 

Enabled Users Identified as Inactive: $($DomainEnabledInactiveUsers.Count) 
Enabled Users With Reversible Encryption Password: $($DomainUsersWithReversibleEncryptionPasswordArray.Count) 
Enabled Users With Password Not Required: $($DomainUserPasswordNotRequiredArray.Count)
Enabled Users With Password Never Expires: $($DomainUserPasswordNeverExpiresArray.Count)
Enabled Users With Kerberos DES: $($DomainKerberosDESUsersArray.Count)
Enabled Users That Do Not Require Kerberos Pre-Authentication: $($DomainUserDoesNotRequirePreAuthArray.Count)
Enabled Users With SID History: $($DomainUsersWithSIDHistoryArray.Count)
Enabled users With Password last Changed > 1year: $($DomainUsersWithOldPassword.Count)
Review & clean up as appropriate
"@
$UserOutputFile = $ReportDir + "\ADChecks-DomainUserReport-$Domain-$TimeVal.csv"
$DomainUsers | Export-CSV $UserOutputFile -NoTypeInformation
$UserWithOldPassOutputFile = $ReportDir + "\ADChecks-DomainUserWithOldPass-$Domain-$TimeVal.csv"
$DomainUsersWithOldPassword | Export-CSV $UserWithOldPassOutputFile - NoTypeInformation


## Domain Password Policy (requires PasswordPolicy Module)
#Write-Host "Domain Password Policy for $ADDomainName "  -Fore Cyan
#[array]$DomainPasswordPolicy = Get-ADPasswordPolicy -Domain $ADDomainNetBIOSName -Server $DomainDC
#Write-Output $DomainPasswordPolicy
#Write-Output " "
#$ForestDomainPasswordPolicyFile = $ReportDir + "\ADChecks-DomainPasswordPolicy-$Domain-$TimeVal.csv"
#$DomainPasswordPolicy | Export-CSV $ForestDomainPasswordPolicyFile -NoTypeInformation  



## Default Domain Administrator Account 
$DomainAdminAccountSID = "$($ADDomainInfo.DomainSID)-500"
$DomainDefaultAdminAccount = Get-ADUser $DomainAdminAccountSID -Server $DomainDC -Properties Name,Enabled,Created,PasswordLastSet,LastLogonDate,ServicePrincipalName,SID
Write-Output "$Domain Default Domain Administrator Account:" -Fore Cyan
$DomainDefaultAdminAccount | Select Name,Enabled,Created,PasswordLastSet,LastLogonDate,ServicePrincipalName | Format-Table -AutoSize
$ForestDomainDefaultAdminAccountFile = $ReportDir + "\ADChecks-DomainDefaultAdminAccount-$Domain-$TimeVal.csv"
$DomainDefaultAdminAccount | Export-CSV $ForestDomainDefaultAdminAccountFile -NoTypeInformation  



## KRBTGT Account Password
$DomainKRBTGTAccount = Get-ADUser 'krbtgt' -Server $DomainDC -Properties 'msds-keyversionnumber',Created,PasswordLastSet
Write-Host "$Domain Domain Kerberos Service Account (KRBTGT): `n" -Fore Cyan
$DomainKRBTGTAccount | Select DistinguishedName,Created,PasswordLastSet,'msds-keyversionnumber' | Format-Table -AutoSize
$ForestDomainKRBTGTAccountFile = $ReportDir + "\ADChecks-DomainKRBTGTAccount-$Domain-$TimeVal.csv"
$DomainKRBTGTAccount | Export-CSV $ForestDomainKRBTGTAccountFile -NoTypeInformation  



## Identify AD Admins
$ADAdminArray = @()
$ADAdminMembers = Get-ADGroupMember Administrators -Recursive -Server $DomainDC
ForEach ($ADAdminMemberItem in $ADAdminMembers)
 { 
  TRY 
   {
      Switch ($ADAdminMemberItem.objectClass)
       {
        'User' { [array]$ADAdminArray += Get-ADUser $ADAdminMemberItem -Properties LastLogonDate,PasswordLastSet,ServicePrincipalName -Server $DomainDC }
        'Computer' { [array]$ADAdminArray += Get-ADComputer $ADAdminMemberItem -Properties LastLogonDate,PasswordLastSet -Server $DomainDC }
        'msDS-GroupManagedServiceAccount' { [array]$ADAdminArray += Get-ADServiceAccount $ADAdminMemberItem -Properties LastLogonDate,PasswordLastSet -Server $DomainDC}
       }
   }
  CATCH
   { Write-Warning "The security principal member ($ADAdminMemberItem) may be in another domain or is unreachable" ; $ADAdminArray += $ADAdminMemberItem }
 }
Write-Host " "
Write-Host "$ADDomainName AD Admins: " -Fore Cyan
$ADAdminArray | sort PasswordLastSet | select name,DistinguishedName,PasswordLastSet,LastLogonDate,ObjectClass | Format-Table -AutoSize
Write-Host " "
$ForestDomainADAdminReportFile = $ReportDir + "\ADChecks-ADAdminAccountReport-$Domain-$TimeVal.csv"
$ADAdminArray | Export-CSV $ForestDomainADAdminReportFile -NoTypeInformation 



## Identify AD Admins with SPNs
Write-Host "$ADDomainName AD Admin Accounts with SPNs:" -Fore Cyan
$ADAdminArray | Where {$_.ServicePrincipalName} | Select name,DistinguishedName,ServicePrincipalName | Format-Table -AutoSize
$AdAdminWithSpnFile = $ReportDir + "\ADChecks-AdAdminWithSpnFilepReport-$Domain-$TimeVal.csv"
$ADAdminArray | Export-CSV $AdAdminWithSpnFile -NoTypeInformation 


## Identify Domain Users with SPNs
Write-Host "$ADDomainName Domain User Accounts with SPNs:" -Fore Cyan
$DomainEnabledUsers | Where {$_.ServicePrincipalName} | Select name,DistinguishedName,ServicePrincipalName | Format-Table -AutoSize
$AdUsersWithSpnFile = $ReportDir + "\ADChecks-AdUsersWithSpnFilepReport-$Domain-$TimeVal.csv"
$DomainEnabledUsers | Export-CSV $AdUsersWithSpnFile -NoTypeInformation 


## Protected Users group membership, compare with AD Admins
$ProtectedUsersGroupMembership = Get-ADGroupMember 'Protected Users'  -Server $DomainDC
Write-Host "$ADDomainName Domain Protected Users Group Membership:" -Fore Cyan
$ProtectedUsersGroupMembership | Select name,DistinguishedName,objectClass | Format-Table
$ForestDomainProtectedUsersGroupMembershipFile = $ReportDir + "\ADChecks-ProtectedUsersGroupMembershipReport-$Domain-$TimeVal.csv"
$ProtectedUsersGroupMembership | Export-CSV $ForestDomainProtectedUsersGroupMembershipFile -NoTypeInformation 


## Privileged AD Group Array
$ADPrivGroupArray = @(
 'Administrators',
 'Domain Admins',
 'Enterprise Admins',
 'Schema Admins',
 'Account Operators',
 'Server Operators',
 'Group Policy Creator Owners',
 'DNSAdmins',
 'Enterprise Key Admins',
 'Exchange Domain Servers',
 'Exchange Enterprise Servers',
 'Exchange Admins',
 'Organization Management',
 'Exchange Windows Permissions'
)

Write-Host "DOMAIN PRIVILEGED AD GROUPS"
Write-Host "============================"



## Discover Default privileged group membership 
ForEach ($ADPrivGroupItem in $ADPrivGroupArray)
 {
    $ADPrivGroupItemGroupMembership = @()
    TRY 
     { 
        $ADPrivGroupItemGroupMembership = Get-ADGroupMember $ADPrivGroupItem -Server $DomainDC 
        IF ($ADPrivGroupItemGroupMembership.count -ge 1)
         {
            Write-Host "$ADDomainName Domain $ADPrivGroupItem Group:" -Fore Cyan
            $ADPrivGroupItemGroupMembership | Select name,DistinguishedName,objectClass | Format-Table
			$ADPrivGroupItemGroupMembershipFile = $ReportDir + "\ADChecks-PrivGroups-$Domain-$ADPrivGroupItem-$TimeVal.csv"
			$ADPrivGroupItemGroupMembership | Export-CSV $ADPrivGroupItemGroupMembershipFile -NoTypeInformation 
         }
        ELSE
         { Write-Host "$ADDomainName Domain $ADPrivGroupItem Group:  No members" -Fore Cyan }
     }
    CATCH
     { Write-Warning "An error occured when attempting to enumerate group membership for the group $ADPrivGroupItem in the domain $Domain using the DC $DomainDC" }
    
    Write-Host ""
 }
TRY 
 { 
    [array]$ADPrivGroupArray = Get-ADGroup -filter {Name -like "*VMWare*"}  -Server $DomainDC
    ForEach ($ADPrivGroupItem in $ADPrivGroupArray)
     {
        $ADPrivGroupItemGroupMembership = Get-ADGroupMember $ADPrivGroupItem.SamAccountName -Server $DomainDC 
        IF ($ADPrivGroupItemGroupMembership.count -ge 1)
         {
            Write-Host "$ADDomainName Domain $ADPrivGroupItem Group:" -Fore Cyan
            $ADPrivGroupItemGroupMembership | Select name,DistinguishedName,objectClass | Format-Table

         }
        ELSE
         { Write-Host "$ADDomainName Domain $ADPrivGroupItem Group: No members" -Fore Cyan }
     }
    }
CATCH
    { Write-Warning "An error occured when attempting to enumerate group membership for the group $ADPrivGroupItem in the domain $Domain using the DC $DomainDC" }
    
	

## Identify Accounts with Kerberos Delegation (time consuming)
$KerberosDelegationArray = @()
[array]$KerberosDelegationObjects =  Get-ADObject -filter { ((UserAccountControl -BAND 0x0080000) -OR (UserAccountControl -BAND 0x1000000) -OR (msDS-AllowedToDelegateTo -like '*') -OR (msDS-AllowedToActOnBehalfOfOtherIdentity -like '*')) -AND (PrimaryGroupID -ne '516') -AND (PrimaryGroupID -ne '521') } -Server $DomainDC -prop Name,ObjectClass,PrimaryGroupID,UserAccountControl,ServicePrincipalName,msDS-AllowedToDelegateTo,msDS-AllowedToActOnBehalfOfOtherIdentity -SearchBase $DomainDN 

ForEach ($KerberosDelegationObjectItem in $KerberosDelegationObjects)
 {
    IF ($KerberosDelegationObjectItem.UserAccountControl -BAND 0x0080000)
     { $KerberosDelegationServices = 'All Services' ; $KerberosType = 'Unconstrained' }
    ELSE 
     { $KerberosDelegationServices = 'Specific Services' ; $KerberosType = 'Constrained' } 

    IF ($KerberosDelegationObjectItem.UserAccountControl -BAND 0x1000000)
     { $KerberosDelegationAllowedProtocols = 'Any (Protocol Transition)' ; $KerberosType = 'Constrained with Protocol Transition' }
    ELSE
     { $KerberosDelegationAllowedProtocols = 'Kerberos' }

    IF ($KerberosDelegationObjectItem.'msDS-AllowedToActOnBehalfOfOtherIdentity')
     { $KerberosType = 'Resource-Based Constrained Delegation'  } 

    $KerberosDelegationObjectItem | Add-Member -MemberType NoteProperty -Name Domain -Value $Domain -Force
    $KerberosDelegationObjectItem | Add-Member -MemberType NoteProperty -Name KerberosDelegationServices -Value $KerberosDelegationServices -Force
    $KerberosDelegationObjectItem | Add-Member -MemberType NoteProperty -Name DelegationType -Value $KerberosType -Force
    $KerberosDelegationObjectItem | Add-Member -MemberType NoteProperty -Name KerberosDelegationAllowedProtocols -Value $KerberosDelegationAllowedProtocols -Force

    [array]$KerberosDelegationArray += $KerberosDelegationObjectItem
 }
Write-Host ""
Write-Host "$Domain Domain Accounts with Kerberos Delegation:" -Fore Cyan
$KerberosDelegationArray | Sort DelegationType | Select DistinguishedName,DelegationType,Name,ServicePrincipalName | Format-Table -AutoSize
$KerberosDelegationReportFile = $ReportDir + "\ADChecks-KerberosDelegationReport-$Domain-$TimeVal.csv"
$KerberosDelegationArray | Sort DelegationType | Export-CSV $KerberosDelegationReportFile -NoTypeInformation 


## Get Domain Permissions
Write-Output "Gathering Domain Permissions for $Domain"
$ForestDomainObjectData = Get-ADObject $ADDomainInfo.DistinguishedName -Properties * -Server $DomainDC
$ForestDomainObjectSecurityData = $ForestDomainObjectData.nTSecurityDescriptor.Access
$ForestDomainObjectPermissions = @()
ForEach ($ForestDomainObjectSecurityDataItem in $ForestDomainObjectSecurityData)
 {
    $ObjectTypeName = Get-NameForGUID $ForestDomainObjectSecurityDataItem.ObjectType -ForestDNSName $ForestDNSName
    $InheritedObjectTypeName = Get-NameForGUID $ForestDomainObjectSecurityDataItem.InheritedObjectType -ForestDNSName $ForestDNSName

    $ForestDomainObjectSecurityDataItem | Add-Member -MemberType NoteProperty -Name Domain -Value $Domain -Force
    $ForestDomainObjectSecurityDataItem | Add-Member -MemberType NoteProperty -Name ObjectTypeName -Value $ObjectTypeName -Force
    $ForestDomainObjectSecurityDataItem | Add-Member -MemberType NoteProperty -Name InheritedObjectTypeName -Value $InheritedObjectTypeName -Force

    [array]$ForestDomainObjectPermissions += $ForestDomainObjectSecurityDataItem
 }
$ForestDomainObjectPermissionFile = $ReportDir + "\ADChecks-DomainRootPermissionReport-$Domain-$TimeVal.csv"
$ForestDomainObjectPermissions | Sort IdentityReference | Select IdentityReference,ActiveDirectoryRights,InheritedObjectTypeName,ObjectTypeName,`
InheritanceType,ObjectFlags,AccessControlType,IsInherited,InheritanceFlags,PropagationFlags,ObjectType,InheritedObjectType | `
Export-CSV $ForestDomainObjectPermissionFile -NoTypeInformation  
Write-Host "Active Directory Domain Permission report saved to the file $ForestDomainObjectPermissionFile" -Fore Cyan
Write-Host ""



## Duplicate SPNs (time consuming)
Write-Host "AD Forest Duplicate SPN Report:" -Fore Cyan
$SetSPN = SetSPN -X -F | where {$_ -notlike "Processing entry*"}
$SetSPN
$ADForestDuplicateSPNsFile = $ReportDir + "\ADChecks-ADForestDuplicateSPNReport-$Domain-$TimeVal.txt"
$SetSPN | Out-File $ADForestDuplicateSPNsFile


## Scan SYSVOL for Group Policy Preference Passwords (time consuming OR EDR blokcing us ? )
Write-Host "$Domain SYSVOL Scan for Group Policy Preference Passwords:" -Fore Cyan
$DomainSYSVOLShareScan = "\\$Domain\SYSVOL\$Domain\Policies\*.xml"
$GPPPasswordData = findstr /S /I cpassword $DomainSYSVOLShareScan 
$GPPPasswordData
$GPPPasswordDataReportFile = $ReportDir + "\ADChecks-GPPPasswordDataReport-$Domain-$TimeVal.txt"
$GPPPasswordData | Out-File $GPPPasswordDataReportFile


## Get GPO Owners
[Array]$DomainGPOs = Get-GPO -All -Domain $Domain
$DomainGPOs | Select DisplayName,Owner | Format-Table -AutoSize
$DomainGPODataReportFile = $ReportDir + "\ADChecks-DomainGPOData-$Domain-$TimeVal.csv"
$DomainGPOs | Out-File $DomainGPODataReportFile

####
$EndMessageText = 
@"

Total Run Time: $($ScriptTimer.Elapsed.ToString())
Script log file: $LogFile
DAta files generated and saved to $ReportDir

"@
$EndMessageText
