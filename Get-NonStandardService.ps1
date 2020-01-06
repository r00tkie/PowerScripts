function Get-NonstandardService {
<#
.SYNOPSIS

Returns services where the associated binaries are either not signed, or are
signed by an issuer not matching 'Microsoft'.

Author: Will Schroeder (@harmj0y)
License: BSD 3-Clause
Required Dependencies: None
#>
    [CmdletBinding()]
    Param()

    function CloneObject($Object) {
        $NewObj = New-Object PsObject
        $Object.psobject.Properties | ForEach-Object { Add-Member -MemberType NoteProperty -InputObject $NewObj -Name $_.Name -Value $_.Value }
        $NewObj
    }

    function Get-BinaryBasePath {

        [CmdletBinding()]
        Param(
            [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
            [Alias('PathName', 'FilePath')]
            [String]
            $Path
        )

        if ($Path -and ($Path -match '^\W*(?<ServicePath>[a-z]:\\.+?(\.exe|\.dll|\.sys))\W*')) {
            $Matches['ServicePath']
        }
        else {
            Write-Warning "Regex failed for the following path: $Path"
        }
    }

    function Get-PEMetaData {

        [CmdletBinding()]
        param($Path)

        try {
            $FullPath = Resolve-Path -Path $Path -ErrorAction Stop
            try {
                $Null = [Reflection.AssemblyName]::GetAssemblyName($FullPath)
                $IsDotNet = $True
            }
            catch {
                $IsDotNet = $False
            }

            $Signature = Get-AuthenticodeSignature -FilePath $FullPath -ErrorAction SilentlyContinue
            if ($Signature -and ($Signature.Status -eq 'NotSigned')) {
                $Signed = $False
                $Issuer = $Null
            }
            else {
                $Signed = $True
                $Issuer = $Signature.SignerCertificate.Issuer
            }

            $Out = New-Object PSObject
            $Out | Add-Member Noteproperty 'Path' $FullPath
            $Out | Add-Member Noteproperty 'Signed' $Signed
            $Out | Add-Member Noteproperty 'Issuer' $Issuer
            $Out | Add-Member Noteproperty 'IsDotNet' $IsDotNet
            $Out
        }
        catch {
            Write-Warning "Unable to resolve path: $Path"
        }
    }

    $MetadataCache = @{}
    Get-WmiObject -Class win32_Service -Property Name,PathName,StartMode,State,ProcessID | Where-Object { $_.PathName } | ForEach-Object {
        $BasePath = Get-BinaryBasePath -Path $_.PathName
        $ServiceName = $_.Name

        Write-Verbose "[Get-NonstandardService] Service $ServiceName : $BasePath"

        if ($MetadataCache[$BasePath]) {
            $Metadata = $MetadataCache[$BasePath]
        }
        else {
            $Metadata = Get-PEMetaData -Path $BasePath
            $MetadataCache[$BasePath] = $Metadata
        }

        $ObjectMetadata = CloneObject $Metadata
        $ObjectMetadata | Add-Member Noteproperty 'Name' $ServiceName
        $ObjectMetadata | Add-Member Noteproperty 'PathName' $_.PathName
        $ObjectMetadata | Add-Member Noteproperty 'StartMode' $_.StartMode
        $ObjectMetadata | Add-Member Noteproperty 'State' $_.State
        $ObjectMetadata | Add-Member Noteproperty 'ProcessID' $_.ProcessID
        $ObjectMetadata
    } | Where-Object {(-not $_.Signed) -or ($_.Issuer -notmatch 'Microsoft')}
}

