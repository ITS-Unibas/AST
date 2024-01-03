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

        # Move the current results to Archive (each 1st day of the month)
        Move-ResultsToArchive

        $StartTime = Get-Date
        $config = Read-ConfigFile
        $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
        $resultsPath = Join-Path -Path $rootPath -ChildPath $Config.Logging.ResultsPath
        $maxResultFiles = $config.Logging.MaxResultFiles
        $astWishlist = $config.Application.WishlistPath
    }

    process {
        # Get list of installed packages from Chocolatey and loop through them to check for updates
        $foundPackages = Get-OutdatedPackages
        $outdatedPackages = $foundPackages.outdatedPackages # Needed to write it like this because $outdatedPackages returns doubled contents! 
        $notOutdatedPackages = $foundPackages.notOutdatedPackages

        # Add new packages (from add-packages.txt list) for AST to be tested
        $newManuallyAddedPackages = Add-NewPackagesForTesting -wishlist $astWishlist
        if ($newManuallyAddedPackages.packages.Count -ne 0){
            $outdatedPackages = $outdatedPackages + $newManuallyAddedPackages.packages
        }

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
                # Check if outdated Packages were found and give a meaningful output (processing package x of y)
                Write-Log -Message "Starting automated Software-Testing for: $outdatedPackageName (previous version: $outdatedPackageInstalledVersion - new version: $outdatedPackageLatestVersion)" -Severity 1

                # Container for results
                $newPackage = [PSCustomObject]@{
                    TimeStamp = ""
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
                    Dependencies = @()
                    UninstallDependenciesExitCode = @()
                    UninstallDependenciesExitMessage = @()
                }
                
                # Get package dependencies
                $dependencies = Get-PackageDependencies -packageName $outdatedPackageName

                $timeStamp = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() -replace "\.", "/"
                $newPackage.TimeStamp = $timeStamp
                $newPackage.PackageName = $outdatedPackageName
                $newPackage.InstalledVersion = $outdatedPackageInstalledVersion
                $newPackage.LatestVersion = $outdatedPackageLatestVersion
                $newPackage.Dependencies = $dependencies
                
                # Update the outdated package
                $updateResult = Install-SWPackage -Package $outdatedPackageName -update

                $newPackage.UpdateExitCode = $updateResult.ExitCode
                $newPackage.UpdateExitMessage = $updateResult.Message

                # Check if the update-process was successful or not and move on if so
                if ($updateResult.ExitCode -eq 0){
                    $originalSoftwareName = Get-OriginalSoftwareName -package $outdatedPackageName -version $outdatedPackageInstalledVersion

                    if ($originalSoftwareName){
                        Write-Log -Message "Found original Softwarename for: $($newPackage.PackageName) - `"$($originalSoftwareName)`"" -Severity 0
                    } else {
                        Write-Log -Message "No original Softwarename found for: $($newPackage.PackageName). Results may not be accurate enough!" -Severity 1
                    }

                    $returnHDSFPU, $DesktopShortcuts = Test-HasNoDesktopShortcutForPublicUser -packageName $outdatedPackageName -originalName $originalSoftwareName

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

                    # Check if there are dependencies for the package to be removed befor uninstalling the package itself
                    if ($newPackage.Dependencies -ne "-"){

                        Write-Log -Message "Found dependencies for $($newPackage.PackageName):" -Severity 0
                        foreach ($dependency in $newPackage.Dependencies){
                            Write-Log -Message $dependency -Severity 0
                        }

                        # Uninstall all dependencies
                        foreach ($dependency in $newPackage.Dependencies){
                            $dependencyPackageName = $dependency
                        
                            $uninstallResult = Uninstall-SWPackage -packageName $dependencyPackageName

                            $newPackage.UninstallDependenciesExitCode += $uninstallResult.ExitCode
                            $newPackage.UninstallDependenciesExitMessage += $uninstallResult.Message
                        }            
                    } else {
                        $newPackage.UninstallDependenciesExitCode = "-"
                        $newPackage.UninstallDependenciesExitMessage = "-"
                    }

                    # Uninstall the updated package to see if an installation process succeeds with a previous version installed
                    $returnUninstallation = Uninstall-SWPackage -packageName $outdatedPackageName

                    $newPackage.UninstallExitCode = $returnUninstallation.ExitCode
                    $newPackage.UninstallExitMessage = $returnUninstallation.Message

                    # Install the outdated package again to be ready for the next update-testing
                    $installResult = Install-SWPackage -Package $outdatedPackageName
    
                    $newPackage.InstallExitCode = $installResult.ExitCode
                    $newPackage.InstallExitMessage = $installResult.Message

                    # Install all dependencies again to be ready for the next update-testing
                    if ($newPackage.Dependencies -ne "-"){
                        foreach ($dependency in $newPackage.Dependencies){
                            $dependencyPackageName = $dependency
                        
                            Install-SWPackage -Package $dependencyPackageName
                        }            
                    }

                    # Write all results to $newPackages
                    $newPackages.Add($newPackage.PackageName, $newPackage)

                } else {
                    # the update process did not succeed: contiune with the next outdated Package. Reason: we can not be sure if the unsuccessful update crashed something

                    $newPackage.HasNoDesktopShortcutForPublicUser = "false"
                    $newPackage.HasNotMultipleAddRemoveEntries = "false"
                    $newPackage.UninstallExitCode = "-"
                    $newPackage.UninstallExitMessage = "-"
                    $newPackage.InstallExitCode = "-"
                    $newPackage.InstallExitMessage = "-"
                    $newPackage.Dependencies = "-"
                    $newPackage.UninstallDependenciesExitCode = "-"
                    $newPackage.UninstallDependenciesExitMessage = "-"

                    
                    $newPackages.Add($newPackage.PackageName, $newPackage)
                    continue
                }
            }
        }
        
        # Add all not-outdated Packages (= packages that failed in the last run) to the $oldPackages-Array
        if ($notOutdatedPackages.Count -ne 0){
            $oldPackages = @{}

            foreach ($notOutdatedPackage in $notOutdatedPackages){
                # Get the latest results.json file
                $latestResultsJSONFile = Get-ChildItem -Path $resultsPath -Filter "*.json" | Sort-Object CreationTime | Select-Object -Last 1
                $latestResultsJSONFilePath = Join-Path $latestResultsJSONFile.PSParentPath $latestResultsJSONFile.Name
                $latestResultsJSON = Get-Content -Path $latestResultsJSONFilePath
                $latestResults = $latestResultsJSON | ConvertFrom-Json
                
                # Container for results
                $oldPackage = [PSCustomObject]@{
                    TimeStamp = ""
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
    
                $notOutdatedPackageName = $notOutdatedPackage.PackageName
    
                $oldPackage.TimeStamp = $latestResults.$($notOutdatedPackageName).TimeStamp
                $oldPackage.PackageName = $notOutdatedPackageName
                $oldPackage.InstalledVersion = $latestResults.$($notOutdatedPackageName).InstalledVersion
                $oldPackage.LatestVersion = $latestResults.$($notOutdatedPackageName).LatestVersion
                $oldPackage.UpdateExitCode = $latestResults.$($notOutdatedPackageName).UpdateExitCode
                $oldPackage.UpdateExitMessage = $latestResults.$($notOutdatedPackageName).UpdateExitMessage
                $oldPackage.HasNoDesktopShortcutForPublicUser = $latestResults.$($notOutdatedPackageName).HasNoDesktopShortcutForPublicUser
                $oldPackage.HasNotMultipleAddRemoveEntries = $latestResults.$($notOutdatedPackageName).HasNotMultipleAddRemoveEntries
                $oldPackage.UninstallExitCode = $latestResults.$($notOutdatedPackageName).UninstallExitCode
                $oldPackage.UninstallExitMessage = $latestResults.$($notOutdatedPackageName).UninstallExitMessage
                $oldPackage.InstallExitCode = $latestResults.$($notOutdatedPackageName).InstallExitCode
                $oldPackage.InstallExitMessage = $latestResults.$($notOutdatedPackageName).InstallExitMessage
    
                $oldPackages.Add($notOutdatedPackageName, $oldPackage)
    
            }
        }
        
        # Sort all Packages alphabetically and format them to export to a JSON-File
        $allPackages = if($newPackages){$newPackages}
        $allPackages = if($oldPackages){$allPackages + $oldPackages} else {$allPackages}

        if ($allPackages.Count -ne 0){
            $allPackages = $allPackages.GetEnumerator() | Sort-Object -Property Name
            $allNewPackages = Add-ToAllNewPackages -packages $allPackages
        }
        
    }

    end {
        if (($outdatedPackages.Count -ne 0) -or ($notOutdatedPackages.Count -ne 0)){
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

            $resultsFilePath = Join-Path -Path $resultsPath -ChildPath "$($Config.Logging.ResultsLogPrefix)_$(Get-Date -Format yyyyMMdd_HHmmss).json"
            $allNewPackages | ConvertTo-Json | Out-File $resultsFilePath
        }

        $runTime = New-TimeSpan -Start $StartTime -End (Get-Date)
        $global:packagingWorkflowDuration = "{0:d2}:{1:d2}:{2:d2}" -f ($runTime.Hours), ($runTime.Minutes), ($runTime.Seconds)
        Write-Log "The packaging Workflow took $global:packagingWorkflowDuration h." -Severity 1

        # Write results to Confluence page only if new packages were tested
        if ($outdatedPackages.Count -ne 0){
            Move-ToConfluence -JsonFilePath $resultsFilePath -DesktopShortcuts $DesktopShortcuts
        }

        $runTimeWithConfluenceUpload = New-TimeSpan -Start $StartTime -End (Get-Date)
        $Duration = "{0:d2}:{1:d2}:{2:d2}" -f ($runTimeWithConfluenceUpload.Hours), ($runTimeWithConfluenceUpload.Minutes), ($runTimeWithConfluenceUpload.Seconds)
        Write-Log "The process took $Duration. Finished." -Severity 1
    }
}