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
    Updated:     2023-04-25
    Version:     1.1.0
    #>
    [CmdletBinding()]
    param(
    )

    begin {
        $config = Read-ConfigFile
        $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
        $resultsPath = Join-Path -Path $rootPath -ChildPath $Config.Logging.ResultsPath
    } 
    
    process {
        # Get the latest results.json file
        $latestResultsJSONFile = Get-ChildItem -Path $resultsPath -Filter "*.json" | Sort-Object CreationTime | Select-Object -Last 1
        $latestResultsJSONFilePath = Join-Path $latestResultsJSONFile.PSParentPath $latestResultsJSONFile.Name
        $latestResultsJSON = Get-Content -Path $latestResultsJSONFilePath
        $latestResults = $latestResultsJSON | ConvertFrom-Json
        $latestCheckedPackages = $latestResults.PSObject.Properties.Name
        
        # Get all outdated Chocolatey-Packages
        Write-Log "Looking for outdated packages." -Severity 1
        $outdatedChocolateyPackagesRaw = choco outdated --ignore-unfound --limit-output

        $outdatedChocolateyPackages = $outdatedChocolateyPackagesRaw | ForEach-Object {
            $packageName = ($_.split("|"))[0]
            $installedVersion = ($_.split("|"))[1]
            $latestVersion = ($_.split("|"))[2]
            [PSCustomObject]@{
                PackageName = $packageName
                InstalledVersion = $installedVersion
                LatestVersion = $latestVersion
            }
        }

        $getOutdatedPackages = New-Object System.Collections.ArrayList
        $getNotOutdatedPackages = New-Object System.Collections.ArrayList

        # Check if an outdated package was already tested (e.g. because it failed installing or updating)
        # Check if the package update/installation/uninstall failed and only proceed if so
        Write-Log "Checking for unsuccessful previous tests..." -Severity 1

        foreach ($package in $outdatedChocolateyPackages){
            $packageNameToTest = $package.PackageName
            $resultsTimeStamp = $latestResults.$($packageNameToTest).TimeStamp
            # if next step is true: package was already tested!            
            if ($packageNameToTest -in $latestCheckedPackages){
                
                $updateExitMessage = $latestResults.$($packageNameToTest).UpdateExitMessage
                $uninstallExitMessage = $latestResults.$($packageNameToTest).UninstallExitMessage
                $installationExitMessage = $latestResults.$($packageNameToTest).InstallExitMessage

                # check if previous test failed and only move
                if (!(($updateExitMessage -eq "-") -and ($uninstallExitMessage -eq "-") -and ($installationExitMessage -eq "-"))){
                    $latestVersionToTest = $latestResults.$($packageNameToTest).LatestVersion
                    # Check for version to be sure that the same package was already tested!
                    if ([Version]$latestVersionToTest -eq [version]($package.LatestVersion)){
                        Write-Log -Message "Package: $package unsuccessfully tested in the last run!" -Severity 1
                        # Check if the package on the Nexus Repo was changed by comparing the timestamps (Nexus-timestamp of the package and timestamp of the json-File)
                        Write-Log "Checking if publish date for $PackageNameToTest@$latestVersionToTest is current..." -Severity 1
                        $timeStamp = Get-PackageTimeStampOnRepo -packageName $packageNameToTest -packageVersion $latestVersionToTest # returns a time-stamp
    
                        # Check if timeStamp could be determined
                        if ($timeStamp){
                            # if the returned timestamp is greater than the creation-time of the JSON-File: Changes were made to the package and pushed to the Repo! Go on and test again:
                            # if the returned timestamp is lower than the creation-time of the JSON-File: No changes were made to the package°
                            if ($timeStamp -ge $resultsTimeStamp){
                                Write-Log "Package on Repo Server seems to be updated - $PackageNameToTest@$latestVersionToTest will be tested again! (Last Test: $resultsTimeStamp. Package publish date: $timeStamp.)" -Severity 1    
                                $getOutdatedPackages.Add($package)
                            } else {
                                Write-Log "Skip testing for $PackageNameToTest@$latestVersionToTest because no packages-changes on the Repo detected." -Severity 1
                                $getNotOutdatedPackages.Add($package)   
                            }
                        } else {
                            Write-Log "Skip testing for $PackageNameToTest@$latestVersionToTest because publish date could not be determined!" -Severity 2
                            $getNotOutdatedPackages.Add($package)
                            Continue
                        }
                    }
                }
                
            } else {
                $getOutdatedPackages.Add($package)
            }
        }


        # Add all outdated packages together
        return @{outdatedPackages = $getOutdatedPackages; notOutdatedPackages = $getnotOutdatedPackages}
    } 
    
    end {
    }

}