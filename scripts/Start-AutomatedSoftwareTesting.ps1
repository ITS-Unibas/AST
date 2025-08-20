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
        $timedOutPackages = @()
        $packageTimeout = 3 * 60 * 60 # 3 hours in seconds
        
        # create ResultsLogFileFolder if not available and setup for iterative writing
        if (-Not (Test-Path $resultsPath -ErrorAction SilentlyContinue)) {
            $null = New-Item -ItemType directory -Path $resultsPath
        }
        
        # setup results file path for iterative updates
        $resultsFilePath = Join-Path -Path $resultsPath -ChildPath "$($Config.Logging.ResultsLogPrefix)_$(Get-Date -Format yyyyMMdd_HHmmss).json"
        $allPackagesResults = @{}
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
                $packageStartTime = Get-Date
                $outdatedPackageName = $outdatedPackage.PackageName
                $outdatedPackageInstalledVersion = $outdatedPackage.InstalledVersion
                $outdatedPackageLatestVersion = $outdatedPackage.LatestVersion
                # Check if outdated Packages were found and give a meaningful output (processing package x of y)
                Write-Log -Message "Starting automated Software-Testing for: $outdatedPackageName (previous version: $outdatedPackageInstalledVersion - new version: $outdatedPackageLatestVersion)" -Severity 1
                
                $packageCompleted = $false
                $timeoutReached = $false
                
                # Create timeout timer
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                
                try {
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
                    
                    # Check timeout before each major operation
                    if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                        Write-Log -Message "Timeout reached for package: $outdatedPackageName during initialization" -Severity 2
                        $timedOutPackages += $outdatedPackageName
                        $timeoutReached = $true
                        throw "Package timeout reached"
                    }
                    
                    # Get package dependencies
                    $dependencies = Get-PackageDependencies -packageName $outdatedPackageName

                    $timeStamp = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() -replace "\.", "/"
                    $newPackage.TimeStamp = $timeStamp
                    $newPackage.PackageName = $outdatedPackageName
                    $newPackage.InstalledVersion = $outdatedPackageInstalledVersion
                    $newPackage.LatestVersion = $outdatedPackageLatestVersion
                    $newPackage.Dependencies = $dependencies
                    
                    # Check timeout before update
                    if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                        Write-Log -Message "Timeout reached for package: $outdatedPackageName before update" -Severity 2
                        $timedOutPackages += $outdatedPackageName
                        $timeoutReached = $true
                        throw "Package timeout reached"
                    }
                    
                    # Update the outdated package
                    $updateResult = Install-SWPackage -Package $outdatedPackageName -update

                    $newPackage.UpdateExitCode = $updateResult.ExitCode
                    $newPackage.UpdateExitMessage = $updateResult.Message

                    # Check timeout after update
                    if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                        Write-Log -Message "Timeout reached for package: $outdatedPackageName after update" -Severity 2
                        $timedOutPackages += $outdatedPackageName
                        $timeoutReached = $true
                        throw "Package timeout reached"
                    }

                    # Check if the update-process was successful or not and move on if so
                    if ($updateResult.ExitCode -eq 0){
                        $originalSoftwareName = Get-OriginalSoftwareName -package $outdatedPackageName -version $outdatedPackageInstalledVersion

                        if ($originalSoftwareName){
                            Write-Log -Message "Found original Softwarename for: $($newPackage.PackageName) - `"$($originalSoftwareName)`"" -Severity 0
                        } else {
                            Write-Log -Message "No original Softwarename found for: $($newPackage.PackageName). Results may not be accurate enough!" -Severity 1
                        }

                        # Check timeout before desktop shortcut test
                        if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                            Write-Log -Message "Timeout reached for package: $outdatedPackageName before desktop shortcut test" -Severity 2
                            $timedOutPackages += $outdatedPackageName
                            $timeoutReached = $true
                            throw "Package timeout reached"
                        }

                        $returnHDSFPU, $DesktopShortcuts = Test-HasNoDesktopShortcutForPublicUser -packageName $outdatedPackageName -originalName $originalSoftwareName

                    # Check if NO desktop-Shortcut was found
                    if ($returnHDSFPU){
                        $newPackage.HasNoDesktopShortcutForPublicUser = "true"
                    } else {
                        $newPackage.HasNoDesktopShortcutForPublicUser = "false"
                    }

                        # Check timeout before AppWiz entries test
                        if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                            Write-Log -Message "Timeout reached for package: $outdatedPackageName before AppWiz entries test" -Severity 2
                            $timedOutPackages += $outdatedPackageName
                            $timeoutReached = $true
                            throw "Package timeout reached"
                        }

                        # Check for multiple AppWiz-Entries
                        $returnHMAWE = Test-HasNotMultipleAppWizEntries -packageName $outdatedPackageName -originalName $originalSoftwareName

                        # Check if NOT multiple AppWiz-Entries were found
                        if ($returnHMAWE){
                            $newPackage.HasNotMultipleAddRemoveEntries = "true"
                        } else {
                            $newPackage.HasNotMultipleAddRemoveEntries = "false"
                        }

                        # Check timeout before dependency operations
                        if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                            Write-Log -Message "Timeout reached for package: $outdatedPackageName before dependency operations" -Severity 2
                            $timedOutPackages += $outdatedPackageName
                            $timeoutReached = $true
                            throw "Package timeout reached"
                        }

                        # Check if there are dependencies for the package to be removed befor uninstalling the package itself
                        if ($newPackage.Dependencies -ne "-"){

                            Write-Log -Message "Found dependencies for $($newPackage.PackageName):" -Severity 0
                            foreach ($dependency in $newPackage.Dependencies){
                                Write-Log -Message $dependency -Severity 0
                            }

                            # Uninstall all dependencies
                            foreach ($dependency in $newPackage.Dependencies){
                                # Check timeout before each dependency uninstall
                                if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                                    Write-Log -Message "Timeout reached for package: $outdatedPackageName during dependency uninstall" -Severity 2
                                    $timedOutPackages += $outdatedPackageName
                                    $timeoutReached = $true
                                    throw "Package timeout reached"
                                }

                                $dependencyPackageName = $dependency
                            
                                $uninstallResult = Uninstall-SWPackage -packageName $dependencyPackageName

                                $newPackage.UninstallDependenciesExitCode += $uninstallResult.ExitCode
                                $newPackage.UninstallDependenciesExitMessage += $uninstallResult.Message
                            }            
                        } else {
                            $newPackage.UninstallDependenciesExitCode = "-"
                            $newPackage.UninstallDependenciesExitMessage = "-"
                        }

                        # Check timeout before package uninstall
                        if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                            Write-Log -Message "Timeout reached for package: $outdatedPackageName before package uninstall" -Severity 2
                            $timedOutPackages += $outdatedPackageName
                            $timeoutReached = $true
                            throw "Package timeout reached"
                        }

                        # Uninstall the updated package to see if an installation process succeeds with a previous version installed
                        $returnUninstallation = Uninstall-SWPackage -packageName $outdatedPackageName

                        $newPackage.UninstallExitCode = $returnUninstallation.ExitCode
                        $newPackage.UninstallExitMessage = $returnUninstallation.Message

                        # Check timeout before package reinstall
                        if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                            Write-Log -Message "Timeout reached for package: $outdatedPackageName before package reinstall" -Severity 2
                            $timedOutPackages += $outdatedPackageName
                            $timeoutReached = $true
                            throw "Package timeout reached"
                        }

                        # Install the outdated package again to be ready for the next update-testing
                        $installResult = Install-SWPackage -Package $outdatedPackageName
        
                        $newPackage.InstallExitCode = $installResult.ExitCode
                        $newPackage.InstallExitMessage = $installResult.Message

                        # Install all dependencies again to be ready for the next update-testing
                        if ($newPackage.Dependencies -ne "-"){
                            foreach ($dependency in $newPackage.Dependencies){
                                # Check timeout before each dependency reinstall
                                if ($timer.Elapsed.TotalSeconds -gt $packageTimeout) {
                                    Write-Log -Message "Timeout reached for package: $outdatedPackageName during dependency reinstall" -Severity 2
                                    $timedOutPackages += $outdatedPackageName
                                    $timeoutReached = $true
                                    throw "Package timeout reached"
                                }

                                $dependencyPackageName = $dependency
                            
                                Install-SWPackage -Package $dependencyPackageName
                            }            
                        }

                    # Write all results to $newPackages
                    $newPackages.Add($newPackage.PackageName, $newPackage)
                    $allPackagesResults.Add($newPackage.PackageName, $newPackage)
                    
                    # write results iteratively after each package
                    $currentResults = @{}
                    foreach ($pkg in $allPackagesResults.GetEnumerator()) {
                        $currentResults.Add($pkg.Key, $pkg.Value)
                    }
                    # add old packages to current results
                    if ($oldPackages) {
                        foreach ($oldPkg in $oldPackages.GetEnumerator()) {
                            if (-not $currentResults.ContainsKey($oldPkg.Key)) {
                                $currentResults.Add($oldPkg.Key, $oldPkg.Value)
                            }
                        }
                    }
                    
                    # clean up old result files based on max limit
                    $numResultsFiles = (Get-ChildItem -Path $resultsPath -Filter '*.json' | Measure-Object).Count
                    if ($numResultsFiles -ge $maxResultFiles) {
                        Get-ChildItem $resultsPath | Sort-Object CreationTime | Select-Object -First ($numResultsFiles - $maxResultFiles + 1) | Remove-Item
                    }
                    
                    # write current results
                    $sortedResults = $currentResults.GetEnumerator() | Sort-Object -Property Name
                    $formattedResults = Add-ToAllNewPackages -packages $sortedResults
                    $formattedResults | ConvertTo-Json | Out-File $resultsFilePath
                    
                    Write-Log -Message "Results updated for package: $($newPackage.PackageName)" -Severity 0

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
                    $allPackagesResults.Add($newPackage.PackageName, $newPackage)
                    
                    # write results iteratively for failed packages too
                    $currentResults = @{}
                    foreach ($pkg in $allPackagesResults.GetEnumerator()) {
                        $currentResults.Add($pkg.Key, $pkg.Value)
                    }
                    # add old packages to current results
                    if ($oldPackages) {
                        foreach ($oldPkg in $oldPackages.GetEnumerator()) {
                            if (-not $currentResults.ContainsKey($oldPkg.Key)) {
                                $currentResults.Add($oldPkg.Key, $oldPkg.Value)
                            }
                        }
                    }
                    
                    # clean up old result files based on max limit
                    $numResultsFiles = (Get-ChildItem -Path $resultsPath -Filter '*.json' | Measure-Object).Count
                    if ($numResultsFiles -ge $maxResultFiles) {
                        Get-ChildItem $resultsPath | Sort-Object CreationTime | Select-Object -First ($numResultsFiles - $maxResultFiles + 1) | Remove-Item
                    }
                    
                    # write current results
                    $sortedResults = $currentResults.GetEnumerator() | Sort-Object -Property Name
                    $formattedResults = Add-ToAllNewPackages -packages $sortedResults
                    $formattedResults | ConvertTo-Json | Out-File $resultsFilePath
                    
                    Write-Log -Message "Results updated for failed package: $($newPackage.PackageName)" -Severity 0
                    continue
                    }
                } catch {
                    # handle timeout and other exceptions
                    Write-Log -Message "Exception occurred while testing package: $outdatedPackageName - $_" -Severity 3
                    
                    if (-not $timeoutReached) {
                        # if it wasn't a timeout, add to timed out packages anyway for tracking
                        $timedOutPackages += $outdatedPackageName
                    }
                    
                    # create a timeout result entry
                    $newPackage = [PSCustomObject]@{
                        TimeStamp = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() -replace "\.", "/"
                        PackageName = $outdatedPackageName
                        InstalledVersion = $outdatedPackageInstalledVersion
                        LatestVersion = $outdatedPackageLatestVersion
                        UpdateExitCode = "TIMEOUT"
                        UpdateExitMessage = "Testing timed out or failed: $_"
                        HasNoDesktopShortcutForPublicUser = "TIMEOUT"
                        HasNotMultipleAddRemoveEntries = "TIMEOUT"
                        UninstallExitCode = "TIMEOUT"
                        UninstallExitMessage = "Testing timed out or failed"
                        InstallExitCode = "TIMEOUT"
                        InstallExitMessage = "Testing timed out or failed"
                        Dependencies = "TIMEOUT"
                        UninstallDependenciesExitCode = "TIMEOUT"
                        UninstallDependenciesExitMessage = "Testing timed out or failed"
                    }
                    
                    $newPackages.Add($newPackage.PackageName, $newPackage)
                    $allPackagesResults.Add($newPackage.PackageName, $newPackage)
                    
                    # write results iteratively for timed out packages
                    $currentResults = @{}
                    foreach ($pkg in $allPackagesResults.GetEnumerator()) {
                        $currentResults.Add($pkg.Key, $pkg.Value)
                    }
                    if ($oldPackages) {
                        foreach ($oldPkg in $oldPackages.GetEnumerator()) {
                            if (-not $currentResults.ContainsKey($oldPkg.Key)) {
                                $currentResults.Add($oldPkg.Key, $oldPkg.Value)
                            }
                        }
                    }
                    
                    $numResultsFiles = (Get-ChildItem -Path $resultsPath -Filter '*.json' | Measure-Object).Count
                    if ($numResultsFiles -ge $maxResultFiles) {
                        Get-ChildItem $resultsPath | Sort-Object CreationTime | Select-Object -First ($numResultsFiles - $maxResultFiles + 1) | Remove-Item
                    }
                    
                    $sortedResults = $currentResults.GetEnumerator() | Sort-Object -Property Name
                    $formattedResults = Add-ToAllNewPackages -packages $sortedResults
                    $formattedResults | ConvertTo-Json | Out-File $resultsFilePath
                    
                    Write-Log -Message "Results updated for timed-out package: $($newPackage.PackageName)" -Severity 0
                    continue
                } finally {
                    if ($timer) {
                        $timer.Stop()
                    }
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
        
        # Final results combination for summary purposes only
        $allPackages = if($newPackages){$newPackages}
        $allPackages = if($oldPackages){$allPackages + $oldPackages} else {$allPackages}

        if ($allPackages.Count -ne 0){
            $allPackages = $allPackages.GetEnumerator() | Sort-Object -Property Name
            $allNewPackages = Add-ToAllNewPackages -packages $allPackages
        }
        
    }

    end {
        # Calculate workflow duration
        $runTime = New-TimeSpan -Start $StartTime -End (Get-Date)
        $global:packagingWorkflowDuration = "{0:d2}:{1:d2}:{2:d2}" -f ($runTime.Hours), ($runTime.Minutes), ($runTime.Seconds)
        
        # Log timeout information if any packages timed out
        if ($timedOutPackages.Count -gt 0) {
            Write-Log "The packaging Workflow took $global:packagingWorkflowDuration h. TIMEOUT INFO: $($timedOutPackages.Count) package(s) timed out after 3 hours each: $($timedOutPackages -join ', ')" -Severity 2
        } else {
            Write-Log "The packaging Workflow took $global:packagingWorkflowDuration h. No packages timed out." -Severity 1
        }

        # Write results to Confluence page only if new packages were tested (use the most recent results file)
        if ($outdatedPackages.Count -ne 0){
            if ($resultsFilePath -and (Test-Path $resultsFilePath)) {
                Move-ToConfluence -JsonFilePath $resultsFilePath -DesktopShortcuts $DesktopShortcuts
            }
        }

        $runTimeWithConfluenceUpload = New-TimeSpan -Start $StartTime -End (Get-Date)
        $Duration = "{0:d2}:{1:d2}:{2:d2}" -f ($runTimeWithConfluenceUpload.Hours), ($runTimeWithConfluenceUpload.Minutes), ($runTimeWithConfluenceUpload.Seconds)
        
        if ($timedOutPackages.Count -gt 0) {
            Write-Log "The process took $Duration. Finished with $($timedOutPackages.Count) timeout(s): $($timedOutPackages -join ', ')" -Severity 2
        } else {
            Write-Log "The process took $Duration. Finished successfully." -Severity 1
        }
    }
}