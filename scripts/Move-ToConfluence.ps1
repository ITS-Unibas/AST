function Move-ToConfluence {
    <#
    .SYNOPSIS
        This function collects all results from the JSON-File ($JsonFilePath) and tries to upload these to a specified Confluence-Page
    .DESCRIPTION
        Details for Confluence REST-API https://docs.atlassian.com/atlassian-confluence/REST/6.6.0/
    .NOTES
        FileName:    Move-ToConfluence.ps1
        Author:      Uwe Molnar
        Contact:     uwe.molnar@unibas.ch
        Created:     2023-04-14
        Updated:     2023-04-18
        Version:     1.1.0
    .PARAMETER JsonFilePath
        The path (including the JSON-Filename)to a JSON-File that should be processed.
    .EXAMPLE
        PS> Move-ToConfluence -JsonFilePath "c:\temp\results.json"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath
    )

    begin {
        $config = Read-ConfigFile        
        $confluenceBaseURL = $config.Application.ConfluenceBaseURL
        $ConfluenceResultsPage = $config.Application.ConfluenceResultsPage
        $confluencePageTitle = $config.Application.ConfluencePageTitle
        $confluenceSpaceKey = $config.Application.ConfluenceSpaceKey
        $confluenceBearerToken = $config.Application.ConfluenceBearerToken
        $confluenceCheck = $config.Application.ConfluenceCheckEmoticon # '<ac:emoticon ac:name="tick" />'
        $confluenceCross = $config.Application.ConfluenceCrossEmoticon # '<ac:emoticon ac:name="cross" />'
        $confluenceLightGreen = $config.Application.ConfluenceLightGreen
        $confluenceLightRed = $config.Application.ConfluenceLightRed
        $confluenceLightYellow = $config.Application.ConfluenceLightYellow

        Write-Log "Start uploading the Testing-Results to Confluence-page '$ConfluenceResultsPage'" -Severity 1
    }

    process {
        # Set up details for page content
        if (-Not (Test-Path $JsonFilePath -ErrorAction SilentlyContinue)) {
            Write-Log "No JSON-File for Confluence-Upload found!" -Severity 3
            exit
        }

        $json = Get-Content -Path $JsonFilePath | ConvertFrom-Json

        # Set up the REST API request headers
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $confluenceBearerToken"
        }

        # Check if the page exists
        $pageUrl = "$($confluenceBaseURL)/content"
        $pageQueryParams = @{
            title = $confluencePageTitle
            ConfluenceSpaceKey = $ConfluenceSpaceKey
        }

        try {
            $pageResult = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $pageQueryParams
            if ($pageResult.results) {
                $pageId = $pageResult.results[0].id
            }
        } catch {
            Write-Log "Error: Confluence-Page '$ConfluenceResultsPage' seems not exist!" -Severity 3
            exit
        }

        # Body for Get-Request to get the version and the Body of the confluence page
        $pageUrl = "$($confluenceBaseURL)/content"
        $pageQueryParams = @{
            title = $confluencePageTitle
            ConfluenceSpaceKey = $ConfluenceSpaceKey
            expand = "version,body.view,body.storage"
            status = "current"
        }

        $currentPageContents = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $pageQueryParams
        [int]$currentPageVersion = $currentPageContents.results[0].version.number
        $currentPageBody = $currentPageContents.results[0].body.storage.value
        [int]$newPageVersion = $currentPageVersion + 1

        # Template for the 'Status-Codes' table at the top of the results-page
        $statusTable = "<table><tr><th>Status-Codes</th></tr><tr><td style='background-color: $($confluenceLightGreen)'>Update / Install and Uninstall successful</td></tr><tr><td style='background-color: $($confluenceLightYellow)'>Update / Install and Uninstall successful - BUT Has Desktop-Shortcut and/or multiple AppWiz-Entries</td></tr><tr><td style='background-color: $($confluenceLightRed)'>Update / Install and Uninstall NOT successful</td></tr></table>"
        
        # Remove the 'Status-Codes' table, so that it is only shown once on the results-page
        $statusTablePattern = "<table>.*Status-Codes.*?</table>"
        $currentPageBody = $currentPageBody -replace $statusTablePattern, ""

        # Create a headline for the results
        $date = Get-Date
        $countPackageTesting = ($json.PSObject.Properties.Length).Count
        $headline = "<h1>$date ($countPackageTesting Packages tested)</h1>"

        # Creating the table with the results for the confluence page and set the new page-content with the old contents
        $table = ""
        $tableContent = ""

        $tableHeader = "<table><tr><th>Application Name</th><th>Current Version</th><th>Latest Version</th><th>Update Exit Code</th><th>Update Exit Message</th><th>Has NO Desktop Shortcut For Public User</th><th>Has NOT Multiple Add/Remove Entries</th><th>Uninstall Exit Code</th><th>Uninstall Exit Message</th><th>Install Exit Code</th><th>Install Exit Message</th></tr>"

        foreach ($package in $json.PSObject.Properties) {
            # replace the true or false statements in the JSON-file with the Empticons "(/)" or "(x)" in Confluence
            $package.Value.HasNoDesktopShortcutForPublicUser = if ($package.Value.HasNoDesktopShortcutForPublicUser -eq "true") { $confluenceCheck } else { $confluenceCross }
            $package.Value.HasNotMultipleAddRemoveEntries = if ($package.Value.HasNotMultipleAddRemoveEntries -eq "true") { $confluenceCheck } else { $confluenceCross }

            # Set a background-color (green, yellow or red), depending on the testing results:
            # green: everything okay
            # yellow: Update and Uninstall / Install okay, but a Desktop-Shortcut or/and multiple AppWiz-Entries found
            # red: Update and Uninstall / Install failed

            # Check if Update and Uninstall and Install processes were successful --> yes: green or yellow, no: red
            if (($package.Value.UpdateExitCode -eq "0") -and ($package.Value.InstallExitCode -eq "0") -and ($package.Value.UninstallExitCode -eq "0")){
                # Check if "HasNoDesktopShortcutForPublicUser" and "HasNotMultipleAddRemoveEntries" --> yes: green, no --> yellow
                if (($package.Value.HasNoDesktopShortcutForPublicUser) -and ($package.Value.HasNotMultipleAddRemoveEntries)){
                    # green
                    $tableContent += "<tr><td style='background-color: $($confluenceLightGreen)'>$($package.Name)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.InstalledVersion)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.LatestVersion)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.UpdateExitCode)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.UpdateExitMessage)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.HasNoDesktopShortcutForPublicUser)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.HasNotMultipleAddRemoveEntries)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.UninstallExitCode)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.UninstallExitMessage)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.InstallExitCode)</td><td style='background-color: $($confluenceLightGreen)'>$($package.Value.InstallExitMessage)</td></tr>"
                } else {
                    # yellow
                    $tableContent += "<tr><td style='background-color: $($confluenceLightYellow)'>$($package.Name)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.InstalledVersion)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.LatestVersion)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.UpdateExitCode)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.UpdateExitMessage)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.HasNoDesktopShortcutForPublicUser)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.HasNotMultipleAddRemoveEntries)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.UninstallExitCode)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.UninstallExitMessage)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.InstallExitCode)</td><td style='background-color: $($confluenceLightYellow)'>$($package.Value.InstallExitMessage)</td></tr>"
                }
            } else {
                # red
                $tableContent += "<tr><td style='background-color: $($confluenceLightRed)'>$($package.Name)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.InstalledVersion)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.LatestVersion)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.UpdateExitCode)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.UpdateExitMessage)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.HasNoDesktopShortcutForPublicUser)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.HasNotMultipleAddRemoveEntries)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.UninstallExitCode)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.UninstallExitMessage)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.InstallExitCode)</td><td style='background-color: $($confluenceLightRed)'>$($package.Value.InstallExitMessage)</td></tr>"
            }
            # without background-colors: $tableContent += "<tr><td>$($package.Name)</td><td>$($package.Value.InstalledVersion)</td><td>$($package.Value.LatestVersion)</td><td>$($package.Value.UpdateExitCode)</td><td>$($package.Value.UpdateExitMessage)</td><td>$($package.Value.HasNoDesktopShortcutForPublicUser)</td><td>$($package.Value.HasNotMultipleAddRemoveEntries)</td><td>$($package.Value.UninstallExitCode)</td><td>$($package.Value.UninstallExitMessage)</td><td>$($package.Value.InstallExitCode)</td><td>$($package.Value.InstallExitMessage)</td></tr>"
        }

        $tableEnd = "</table>"
        $table = $tableHeader + $tableContent + $tableEnd

        # Set all body-info together into $pageContent
        $pageContent = $statusTable + $headline + $table + $currentPageBody

        # Build the REST API request body to input the results
        $body = @{
            type = "page"
            title = $confluencePageTitle
            space = @{
                key = $ConfluenceSpaceKey
            }
            body = @{
                storage = @{
                    value = $pageContent
                    representation = "storage"
                }
            }
            version = @{
                number = "$newPageVersion" 
            }
        } | ConvertTo-Json

        # update the confluence page
        $pageUrl = "$($pageUrl)/$($pageId)"
        try {
            $pageResult = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Put -Body $body
        } catch {
            Write-Log "Failed to update Confluence-Page: $($_) `n $($_.Exception.Message)" -Severity 3
            exit
        }
    }

    end{
        Write-Log "Confluence-Page succesfully updated!" -Severity 1
    }
}