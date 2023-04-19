function Get-OutdatedPackages () {
    <#
    .Synopsis
    Gets all outdated packages via Chocolatey 
    .DESCRIPTION
    Gets all outdated packages via Chocolatey and writes them to a PSCustomObject with the packagename, previous and latest version
    .NOTES
    FileName:    Get-OutdatedPackages.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
    )

    begin {
    } 
    
    process {
        $outdatedPackagesRaw = choco outdated --ignore-unfound --limit-output

        $outdatedPackages = $outdatedPackagesRaw | ForEach-Object {
            $packageName = ($_.split("|"))[0]
            $installedVersion = ($_.split("|"))[1]
            $latestVersion = ($_.split("|"))[2]
            [PSCustomObject]@{
                PackageName = $packageName
                InstalledVersion = $installedVersion
                LatestVersion = $latestVersion
            }
        }

        return $outdatedPackages 
    } 
    
    end {
    }

}