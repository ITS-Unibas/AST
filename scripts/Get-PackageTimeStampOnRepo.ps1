function Get-PackageTimeStampOnRepo () {
    <#
    .Synopsis
    Gets the timestamp of a given package on the repostiory
    .DESCRIPTION
    Gets the timestamp of a given package on the repostiory
    .NOTES
    FileName:    Get-PackageTimeStampOnRepo.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-27
    Updated:     2023-04-27
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$packageName,

        [Parameter(Mandatory = $true)]
        [String]$PackageVersion
    )

    begin {
        $config = Read-ConfigFile
    } 
    
    process {           
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $Uri = $Config.Application.RepositoryManagerAPIBaseUrl + "Packages(Id='$PackageName',Version='$PackageVersion')"
        try {
            $Response = Invoke-WebRequest -Uri $Uri -Headers @{Authorization = "Basic $Base64Auth" }
            [xml]$XMLContent = $Response | Select-Object -ExpandProperty Content
            [datetime]$PublishDate = $XMLContent.entry.properties.Published.'#text'
            Write-Log -Message "Publish Date for $PackageName@$PackageVersion is $PublishDate." -Severity 1

            return $PublishDate
        } catch {
            Write-Log "Could not request the timestamp of the package $packageName@$PackageVersion from the Repository! Error: $($_.Exception.Message)." -Severity 2
        }
        return $null
    } 
    
    end {
    }

}
