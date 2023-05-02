function Test-HasNotMultipleAppWizEntries () {
    <#
    .Synopsis
    Function to check if a package has NOT multiple entries in the Add/Remove Programs list
    .DESCRIPTION
    Function to check if a package has NOT multiple entries in the Add/Remove Programs list. Returns $true or $false
    .NOTES
    FileName:    Test-HasNotMultipleAppWizEntries.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$packageName,

        [Parameter()]
        $originalName
    )

    begin {
        Write-Log -Message "Searching for multiple App-Wizard Entries for '$packageName'..." -Severity 0

        function SearchRegistry($package) {
            $entries = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {($_.DisplayName -eq "$package")}
            if ($entries.Count -gt 1) {
                Write-Log -Message "Multiple App-Wizard Entries found for '$packageName'!" -Severity 2
                return $false
            } else {
                Write-Log -Message "NO Multiple App-Wizard Entries found for '$packageName'!" -Severity 1
                return $true
            }
        }

    } 
    
    process {           
        if ($packageName.StartsWith("unibas-")) {
            Write-Log -Message "Cutting of 'unibas-'-Prefix" -Severity 0
            $shortcutName = $packageName.Substring(7)
        } else {
            $shortcutName = $packageName
        }

        if ($originalName){
            SearchRegistry -package $originalName
        } else {
            SearchRegistry -package $shortcutName
        }
        
    } 
    
    end {
    }

}