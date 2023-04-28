function Search-ChocoLogFile () {
    <#
    .Synopsis
    Searches the ChocoLogFile under "C:\ProgramData\chocolatey\logs\choco.summary.log" for all WARNINGS and ERRORS that occured during installation or update / uninstall (if it failed)
    .DESCRIPTION
    Searches the ChocoLogFile under "C:\ProgramData\chocolatey\logs\choco.summary.log" for all WARNINGS and ERRORS that occured during installation or update / uninstall (if it failed)
    .NOTES
    FileName:    Add-ToAllNewPackages.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-19
    Version:     1.0.0
    .EXAMPLE
    How it works:

    1. Take the ChocoLog from "C:\ProgramData\chocolatey\logs\choco.summary.log"
    2. Search for the Pattern "You have {packageName}" from down to top in the file and save the line-number as X
    3. From the line X to the last line in the ChocoLog: Go through each and look for all lines that match "[WARN ]" or "[ERROR]" and save them to an array ARR
    4. The contents of the array ARR should be returned as a String-Array and include all infos as text-messgage for the wiki-page
    
    + dont install or uninstall a sw again if it failed once!!!


    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$package
    )

    begin {
        # Could also be exported to the config.json
        $chocoLogFile = "C:\ProgramData\chocolatey\logs\choco.summary.log"
        $searchPattern = "You have $package"
        $warnErrorPattern = "\[WARN \]|\[ERROR\]"
        $nextLinePattern = ':$|(\s-\s)$'
    } 
    
    process {
        $chocoLogFileContent = Get-Content -Path $chocoLogFile          
        $results = $chocoLogFileContent | Select-String -Pattern $searchPattern
        $lastResult = $results[-1]

        $lastResultLine = $lastResult.LineNumber
        $chocoLogFileLinesCount = $chocoLogFileContent.Length

        $chocoLogFileContentShortend = $chocoLogFileContent[$lastResultLine..$chocoLogFileLinesCount]     
        
        $warningsAndErros = New-Object System.Collections.ArrayList

        foreach ($line in $chocoLogFileContentShortend) {
            if ($line -match $warnErrorPattern){
                $null = $warningsAndErros.Add($line)

                # add the line beneath an error- or warn line, if it ends with ":" or " - " to get the full infos of an error or warning
                if ($line -match $nextLinePattern){
                    $currentLine = $chocoLogFileContentShortend.IndexOf($line)
                    $null = $warningsAndErros.Add($chocoLogFileContentShortend[($currentLine + 1)])
                }
            }
        }

        return $warningsAndErros

    } 
    
    end {
    }
}