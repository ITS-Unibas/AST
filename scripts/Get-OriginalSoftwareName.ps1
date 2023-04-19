function Get-OriginalSoftwareName () {
    <#
    .Synopsis
    If the packageName is not the same as it is in the AppWiz gets the AppWiz-Entry for the package
    .DESCRIPTION
    If the packageName is not the same as it is in the AppWiz gets the AppWiz-Entry for the package. Returns a string with the original Softwarename
    .NOTES
    FileName:    Get-OriginalSoftwareName.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$package,

        [Parameter(Mandatory = $true)]
        [int]$version
    )

    begin {
    } 
    
    process {           
        $chocopath = Join-Path $env:ChocolateyInstall ".chocolatey"
        $softwareAndVersion = "$($package).$($version)"

        try {
            $checkPath = Join-Path $chocopath $softwareAndVersion
            $regFile = ".registry"
            $registryFilePath = Join-Path $checkPath $regFile
            $xmlContent = [xml](Get-Content $registryFilePath -Raw)
            $originalSoftwareName = $xmlContent.registrySnapshot.keys.key.displayName
        }
        catch {
            Write-Log -Message "Something went wrong while extracting the original AppWiz-Name from Chocolatey. Error: $($_.Exception.Message)." -Severity 2
            $originalSoftwareName = ""
        }

        return $originalSoftwareName
    }
    
    end {
    }

}