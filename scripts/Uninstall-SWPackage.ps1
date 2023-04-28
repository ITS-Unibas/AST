function Uninstall-SWPackage () {
    <#
    .Synopsis
    Function to uninstall a package via Chocolatey and return the exit code and message
    .DESCRIPTION
    Function to uninstall a package via Chocolatey and return the exit code and message. Returns a Hashtable with the returnCode and a returnmessage
    .NOTES
    FileName:    Uninstall-SWPackage.ps1
    Author:      Uwe Molnar 
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     2023-04-27
    Version:     1.1.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$packageName
    )

    begin {
        Write-Log -Message "Uninstalling $packageName..." -Severity 1
        $argumentList = "uninstall $packageName --yes"
    } 
    
    process {                   
        $process = Start-Process choco -ArgumentList $argumentList -PassThru -Wait
        $exitCode = $process.exitCode

        if ($exitCode -eq 0) {
            Write-Log -Message "'$packageName' successfully uninstalled." -Severity 1
            $ExitMessage = "-"
        } else {
            $ExitMessage = Search-ChocoLogFile -package $packageName

            Write-Log -Message "An error occurred while uninstalling '$packageName'. Exit-Code: $exitCode" -Severity 3
            Write-Log -Message "Exit-Message: $ExitMessage" -Severity 3
        }
        
        return @{ExitCode = $exitCode; Message = $ExitMessage}
    } 
    
    end {
    }

}