function Add-ToAllNewPackages () {
    <#
    .Synopsis
    Adds an updated package to the newPackages-Object which is written to a json file for history
    .DESCRIPTION
    Adds an updated package to the newPackages-Object which is written to a json file for history. Returns a Hash-Table with allNewPackages formated to export as JSON
    .NOTES
    FileName:    Add-ToAllNewPackages.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$packages
    )

    begin {
    } 
    
    process {           
        $allNewPackages = @{}
            
        foreach ($package in $packages){
            $singlePackage = @{
                "$($package.Name)" = @{
                    InstalledVersion = $($package.Value.InstalledVersion)
                    LatestVersion = $($package.Value.LatestVersion)
                    UpdateExitCode = $($package.Value.UpdateExitCode)
                    UpdateExitMessage = $($package.Value.UpdateExitMessage)
                    HasNoDesktopShortcutForPublicUser = $($package.Value.HasNoDesktopShortcutForPublicUser)
                    HasNotMultipleAddRemoveEntries = $($package.Value.HasNotMultipleAddRemoveEntries)
                    UninstallExitCode = $($package.Value.UninstallExitCode)
                    UninstallExitMessage = $($package.Value.UninstallExitMessage)
                    InstallExitCode = $($package.Value.InstallExitCode)
                    InstallExitMessage = $($package.Value.InstallExitMessage)
                }
            }

            $allNewPackages += $singlePackage
        }
        return $allNewPackages
    } 
    
    end {
    }

}