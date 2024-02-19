function Move-ResultsToArchive {
    <#
    .SYNOPSIS
        This function moves the logs of AST from the current Results-Page to a specified Confluence-Archive-Page to reduce the size of the Results-Page and improve its performance.
        This function runs every 1st day of the month. All current results of AST are moved to a monthly Archive-Page named e. g. "2024-02 [AST-Archive Prod/Test]".
    .DESCRIPTION
        Details for Confluence REST-API https://docs.atlassian.com/atlassian-confluence/REST/6.6.0/
    .NOTES
        FileName:    Move-ResultsToArchive.ps1
        Author:      Uwe Molnar
        Contact:     uwe.molnar@unibas.ch
        Created:     2024-02-19
        Updated:     -
        Version:     2.0.0
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
        $system = $config.Application.System
    }

    process {
        # Get the current day of the month, the current month and the current year
        $today = Get-Date
        $dayOfMonth = $today.Day
        $currentMonth = $today.Month
        $currentYear = $today.Year

        # Set up the REST API request headers for all API requests
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $confluenceBearerToken"
        }

        $pageUrl = "$($confluenceBaseURL)/content"

        # Check if main Archive-Page and montly Archive-Page exist
        ## Check main Achive-Page
        $archivePageQueryParams = @{
            title = $confluenceArchivePageTitle
            ConfluenceSpaceKey = $ConfluenceSpaceKey
            expand = "version"
            status = "current"
        }

        $currentArchivePageContents = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $archivePageQueryParams
        
        if (!($currentArchivePageContents.results)) {
            Write-Log "Error: Confluence-Page '$confluenceArchivePageTitle' seems not to exist - Exit!" -Severity 3
            exit
        }
        
        ## Check montly Archive-Page ($currentMonthPageContents would be empty if the page does not exist yet)
        $idArchiveMainPage = $currentArchivePageContents.results.id
        $monthlyPageTitle = "$($currentYear)-$($currentMonth.ToString("00")) [AST-Archive $system]"

        $monthlyPageQueryParams = @{
            title = $monthlyPageTitle
            ConfluenceSpaceKey = $ConfluenceSpaceKey
            expand = "version"
            status = "current"
        }

        $currentMonthPageContents = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $monthlyPageQueryParams

        # Move the logs of AST Results-Page to the montly Archive-Page if it is the 1st of the month and if the current Month-Page doas not exist yet. If the page exists the backup is already done.
        if (($dayOfMonth -eq 1) -and (!($currentMonthPageContents.Results))) {
            Write-Log "--- It's the 1st day of the month. Start moving the logs of AST Results-Page to the Archive-Page '$monthlyPageTitle' ---" -Severity 1

            # Create monthly backup-Wiki-Page
            Write-Log "Confluence-Page for $($currentYear)-$($currentMonth.ToString("00")) seems not to exist - Create it!" -Severity 2
            
            $bodyMonthlyPage = @{
                type  = "page"
                title = $monthlyPageTitle
                space = @{key = $ConfluenceSpaceKey}
                ancestors = @(@{id = $idArchiveMainPage})
                body  = @{
                    storage = @{
                        value          = ""
                        representation = "storage"
                    }
                }
            } | ConvertTo-Json
            
            try {
                $currentMonthPageContents = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Post -Body $bodyMonthlyPage
            } catch {
                Write-Log "Failed to create Confluence-Page for $($currentYear)-$($currentMonth.ToString("00")) `n $($_.Exception.Message)" -Severity 3
                exit
            }

            Write-Log "Confluence-Page for $($currentYear)-$($currentMonth.ToString("00")) successfully created!" -Severity 1         

            # Set data from the Archive-Month-Page
            [long]$idArchiveMonthPage = $currentMonthPageContents.id  
            [int]$currentMonthPageVersion = $currentMonthPageContents.version.number
            [int]$newMonthPageVersion = $currentMonthPageVersion  + 1

            # Check if the AST Results-Page exists and get its contents
            $resultsPageQueryParams = @{
                title = $confluenceResultsPageTitle
                ConfluenceSpaceKey = $ConfluenceSpaceKey
                expand = "version,body.view,body.storage"
                status = "current"
            }
      
            $pageResult = Invoke-RestMethod -Uri $pageUrl -Headers $headers -Method Get -Body $resultsPageQueryParams
            
            if ($pageResult.results) {
                $pageId = $pageResult.results[0].id
            }else{
                Write-Log "Error: Confluence-Page '$confluenceResultsPageTitle' seems not to exist!" -Severity 3
                exit
            }

            # Get the contents of the AST Results-Page
            $currentPageBody = $pageResult.results[0].body.storage.value
            
            # Build the REST API request body for the monthly Archive-Page
            $body = @{
                type = "page"
                title = $monthlyPageTitle
                space = @{key = $ConfluenceSpaceKey}
                body = @{
                    storage = @{
                        value = $currentPageBody
                        representation = "storage"
                    }
                }
                version = @{
                    number = "$newMonthPageVersion" 
                }
            } | ConvertTo-Json

            # update the Archive-Page
            $archivePageUrl = "$($pageUrl)/$($idArchiveMonthPage)"
            try {
                Invoke-RestMethod -Uri $archivePageUrl -Headers $headers -Method Put -Body $body
            } catch {
                Write-Log "Failed to update Confluence-Page '$monthlyPageTitle' `n $($_.Exception.Message)" -Severity 3
                exit
            }

            # CleanUp AST Results-Page after successful moving the logs to the monthly Archive-Page
            ## Set page-content to empty (with only the statusTablePattern)
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

            ## Build the REST API request body for the AST Results-Page
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

            ## update the AST Results-Page
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