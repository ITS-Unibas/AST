function Move-ResultsToArchive {
    <#
    .SYNOPSIS
        This function moves the logs of AST from the current Results-Page to a specified Confluence-Archive-Page to reduce the size of the Results-Page and improve its performance.
    .DESCRIPTION
        Details for Confluence REST-API https://docs.atlassian.com/atlassian-confluence/REST/6.6.0/
    .NOTES
        FileName:    Move-ResultsToArchive.ps1
        Author:      Uwe Molnar
        Contact:     uwe.molnar@unibas.ch
        Created:     2023-12-27
        Updated:     -
        Version:     1.0.0
    .EXAMPLE
        PS> Move-ResultsToArchive
    #>

    begin {
        $config = Read-ConfigFile        
        $confluenceBaseURL = $config.Application.ConfluenceBaseURL
        $confluenceResultsPageTitle = $config.Application.ConfluenceResultsPageTitle
        $confluenceArchivePageTitle = $config.Application.ConfluenceArchivePageTitle
        $confluenceSpaceKey = $config.Application.ConfluenceSpaceKey
        $confluenceBearerToken = $config.Application.ConfluenceBearerToken
        $confluenceLightGreen = $config.Application.ConfluenceLightGreen
        $confluenceLightRed = $config.Application.ConfluenceLightRed
        $confluenceLightYellow = $config.Application.ConfluenceLightYellow
    }

    process {
        # Get the current day of the month
        $today = Get-Date
        $dayOfMonth = $today.Day

        # Get the date of the last change of the Archive-Page
        # Set up the REST API request headers
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $confluenceBearerToken"
        }

        $pageUrl = "$($confluenceBaseURL)/content"

        # Check if Archive-Page exists
        $archivePageQueryParams = @{
            title = $confluenceArchivePageTitle
            ConfluenceSpaceKey = $ConfluenceSpaceKey
            expand = "version,body.view,body.storage"
            status = "current"
        }

        try {
            $currentArchivePageContents = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $archivePageQueryParams
            if ($currentArchivePageContents.results) {
                $archivePageId = $currentArchivePageContents.results[0].id
            }
        } catch {
            Write-Log "Error: Confluence-Page '$confluenceArchivePageTitle' seems not to exist!" -Severity 3
            exit
        }

        [datetime]$lastChangeDateArchivePage = $currentArchivePageContents.results[0].version.when

        # Move the logs of AST Results-Page to the Archive-Page if it is the 1st of the montg abd the page-edit-date is older than the 1st of the month
        if (($dayOfMonth -eq 1) -and ($lastChangeDateArchivePage -lt ($today.Date))) {
            Write-Log "--- It's the 1st day of the month. Start moving the logs of AST Results-Page to the Archive-Page ---" -Severity 1

            # Set data from the Archive-Page
            [int]$currentArchivePageVersion = $currentArchivePageContents.results[0].version.number
            $currentArchivePageBody = $currentArchivePageContents.results[0].body.storage.value
            [int]$newArchivePageVersion = $currentArchivePageVersion + 1

            # Check if the AST Results-Page exists and get its contents
            $resultsPageQueryParams = @{
                title = $confluenceResultsPageTitle
                ConfluenceSpaceKey = $ConfluenceSpaceKey
                expand = "version,body.view,body.storage"
                status = "current"
            }

            try {
                $pageResult = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $resultsPageQueryParams
                if ($pageResult.results) {
                    $pageId = $pageResult.results[0].id
                }
            } catch {
                Write-Log "Error: Confluence-Page '$confluenceResultsPageTitle' seems not to exist!" -Severity 3
                exit
            }

            # Remove the 'Status-Codes' table from the Archive-Page, so that it is only shown once on after update
            $statusTablePattern = "<table.*>([\s\S]*?)Status-Codes([\s\S]*?)<\/table>"
            $currentArchivePageBody = $currentArchivePageBody -replace $statusTablePattern, ""

            # Get the contents of the AST Results-Page
            $currentPageBody = $pageResult.results[0].body.storage.value

            # Put the contents of the AST Results-Page on top of the Confluence-Archive-Page
            $newArchivePageContent = $currentPageBody + $currentArchivePageBody
            
            # Build the REST API request body for the Archive-Page
            $body = @{
                type = "page"
                title = $confluenceArchivePageTitle
                space = @{
                    key = $ConfluenceSpaceKey
                }
                body = @{
                    storage = @{
                        value = $newArchivePageContent
                        representation = "storage"
                    }
                }
                version = @{
                    number = "$newArchivePageVersion" 
                }
            } | ConvertTo-Json

            # update the Archive-Page
            $archivePageUrl = "$($pageUrl)/$($archivePageId)"
            try {
                Invoke-RestMethod -Uri $archivePageUrl -Headers $headers -Method Put -Body $body
            } catch {
                Write-Log "Failed to update Confluence-Page '$confluenceArchivePageTitle' `n $($_.Exception.Message)" -Severity 3
                exit
            }

            # CleanUp AST Results-Page after successful moving the logs to the Archive-Page
            # Set page-content to empty (with only the statusTablePattern)
            [int]$currentPageVersion = $pageResult.results[0].version.number
            [int]$newPageVersion = $currentPageVersion + 1

            $statusTable = @"
            <table>
                <tr>
                    <th>Status-Codes</th>
                </tr>
                <tr>
                    <td style='background-color: $($confluenceLightGreen)'>Update / Install and Uninstall successful</td>
                </tr>
                <tr>
                    <td style='background-color: $($confluenceLightYellow)'>Update / Install and Uninstall successful - BUT Has Desktop-Shortcut and/or multiple AppWiz-Entries</td>
                </tr>
                <tr>
                    <td style='background-color: $($confluenceLightRed)'>Update / Install and Uninstall NOT successful</td>
                </tr>
            </table>
"@
    
            $newPageBody = $statusTable

            # Build the REST API request body for the AST Results-Page
            $body = @{
                type = "page"
                title = $confluenceResultsPageTitle
                space = @{
                    key = $ConfluenceSpaceKey
                }
                body = @{
                    storage = @{
                        value = $newPageBody
                        representation = "storage"
                    }
                }
                version = @{
                    number = "$newPageVersion" 
                }
            } | ConvertTo-Json

            # update the AST Results-Page
            $pageUrl = "$($pageUrl)/$($pageId)"
            try {
                Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Put -Body $body
            } catch {
                Write-Log "Failed to update Confluence-Page '$confluenceResultsPageTitle' `n $($_.Exception.Message)" -Severity 3
                exit
            }

            Write-Log "Testing-Results succesfully archived and Testing-Results-Page succesfully updated!" -Severity 1

        } else {
            return
        }

    }

    end{
    }
}