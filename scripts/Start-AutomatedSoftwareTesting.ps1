function Start-AutomatedSoftwareTesting {
    <#
    .Synopsis
    This function initiates the workflow for the automated Software-Testing
    .DESCRIPTION
    This function initiates the workflow for the automated Software-Testing
    .NOTES
    FileName:    Start-AutomatedSoftwareTesting.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        Write-Log -Message "Starting automated Software-Testing" -Severity 1
        
        $StartTime = Get-Date
        $config = Read-ConfigFile
        $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
        $resultsPath = Join-Path -Path $rootPath -ChildPath $Config.Logging.ResultsPath
        $maxResultFiles = $Config.Logging.MaxResultFiles
        $resultsFilePath = Join-Path -Path $resultsPath -ChildPath "$($Config.Logging.ResultsLogPrefix)_$(Get-Date -Format yyyyMMdd_HHmmss).json"
    }

    process {
        # Get list of installed packages from Chocolatey and loop through them to check for updates
        $outdatedPackages = Get-OutdatedPackages

        if ($outdatedPackages.Count -eq 0){
            Write-Log -Message "No outdated packages found!" -Severity 0
        } else {
            Write-Log -Message "Outdated packages found:" -Severity 0
            foreach ($outdatedPackage in $outdatedPackages){
                Write-Log -Message " $($outdatedPackage.PackageName): $($outdatedPackage.InstalledVersion)|$($outdatedPackage.LatestVersion)" -Severity 0
            }

            $newPackages = @{}

            # Go through each package and try to check all testing-criterias
            foreach ($outdatedPackage in $outdatedPackages) {
                $outdatedPackageName = $outdatedPackage.PackageName
                $outdatedPackageInstalledVersion = $outdatedPackage.InstalledVersion
                $outdatedPackageLatestVersion = $outdatedPackage.LatestVersion
                # Check if outdated Packages found and give a meaningful output (processing package x of y)
                Write-Log -Message "Starting automated Software-Testing for: $outdatedPackageName (previous version: $outdatedPackageInstalledVersion - new version: $outdatedPackageLatestVersion)" -Severity 1

                # Container for results
                $newPackage = [PSCustomObject]@{
                    PackageName = ""
                    InstalledVersion = ""
                    LatestVersion = ""
                    UpdateExitCode = ""
                    UpdateExitMessage = ""
                    HasNoDesktopShortcutForPublicUser = ""
                    HasNotMultipleAddRemoveEntries = ""
                    UninstallExitCode = ""
                    UninstallExitMessage = ""
                    InstallExitCode = ""
                    InstallExitMessage = ""
                }

                $newPackage.PackageName = $outdatedPackageName
                $newPackage.InstalledVersion = $outdatedPackageInstalledVersion
                $newPackage.LatestVersion = $outdatedPackageLatestVersion

                # Update the outdated package
                $updateResult = Install-SWPackage -Package $outdatedPackageName -update

                $newPackage.UpdateExitCode = $updateResult.ExitCode
                $newPackage.UpdateExitMessage = $updateResult.Message

                # Check if the update-process was successful or not and move on if so
                if ($updateResult.ExitCode -eq 0){
                    #Write-Log -Message "Installation of $($newPackage.PackageName) successful!" -Severity 1

                    $originalSoftwareName = Get-OriginalSoftwareName -package $outdatedPackageName -version $outdatedPackageInstalledVersion
                    
                    Write-Log -Message "Found original Softwarename for: $($newPackage.PackageName) - `"$($originalSoftwareName)`"" -Severity 0

                    $returnHDSFPU = Test-HasNoDesktopShortcutForPublicUser -packageName $outdatedPackageName -originalName $originalSoftwareName

                    # Check if NO desktop-Shortcut was found
                    if ($returnHDSFPU){
                        $newPackage.HasNoDesktopShortcutForPublicUser = "true"
                    } else {
                        $newPackage.HasNoDesktopShortcutForPublicUser = "false"
                    }

                    # Check for multiple AppWiz-Entries
                    $returnHMAWE = Test-HasNotMultipleAppWizEntries -packageName $outdatedPackageName -originalName $originalSoftwareName

                    # Check if NOT multiple AppWiz-Entries were found
                    if ($returnHMAWE){
                        $newPackage.HasNotMultipleAddRemoveEntries = "true"
                    } else {
                        $newPackage.HasNotMultipleAddRemoveEntries = "false"
                    }

                    # Uninstall the updated package to see if an installation process succeeds with a previous version installed
                    $returnUninstallation = Uninstall-SWPackage -packageName $outdatedPackageName

                    $newPackage.UninstallExitCode = $returnUninstallation.ExitCode
                    $newPackage.UninstallExitMessage = $returnUninstallation.Message

                    # Install the outdated package again to be ready for the next update-testing
                    $installResult = Install-SWPackage -Package $outdatedPackageName
    
                    $newPackage.InstallExitCode = $installResult.ExitCode
                    $newPackage.InstallExitMessage = $installResult.Message

                    # Write all results to $newPackages
                    $newPackages.Add($newPackage.PackageName, $newPackage)

                } else {
                    # the update process did not succeed contiune with the next outdated Package. Reason: we can not be sure if the unsuccessful update crashed something

                    $newPackage.HasNoDesktopShortcutForPublicUser = "false"
                    $newPackage.HasNotMultipleAddRemoveEntries = "false"
                    $newPackage.UninstallExitCode = "-"
                    $newPackage.UninstallExitMessage = "-"
                    $newPackage.InstallExitCode = "-"
                    $newPackage.InstallExitMessage = "-"
                    
                    $newPackages.Add($newPackage.PackageName, $newPackage)
                    continue
                }
            }

            # Sort all new Packages alphabetically and format them to export to a JSON-File
            $newPackages = $newPackages.GetEnumerator() | Sort-Object -Property Name
            $allNewPackages = Add-ToAllNewPackages -pacakges $newPackages
        }
    }

    end {
        if ($outdatedPackages.Count -ne 0){
            # Write results to JSON file
            # Create ResultsLogFileFolder if not available and check for maxResultsFiles
            if (-Not (Test-Path $resultsPath -ErrorAction SilentlyContinue)) {
                $null = New-Item -ItemType directory -Path $resultsPath
            }

            $numResultsFiles = (Get-ChildItem -Path $resultsPath -Filter '*.json' | Measure-Object).Count
            if ($numResultsFiles -eq $maxResultFiles) {
                Get-ChildItem $resultsPath | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item
            }
            elseif ($numResultsFiles -gt $maxResultFiles) {
                Get-ChildItem $resultsPath | Sort-Object CreationTime | Select-Object -First ($numResultsFiles - $maxResultFiles + 1) | Remove-Item
            }

            $allNewPackages | ConvertTo-Json | Out-File $resultsFilePath

            # Write results to Confluence page
            Move-ToConfluence -JsonFilePath $resultsFilePath
        }

        $Duration = New-TimeSpan -Start $StartTime -End (Get-Date)
        Write-Log "The process took $Duration. Finished." -Severity 1
    }
}