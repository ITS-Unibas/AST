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
    Updated:     2023-04-19
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$packageName
    )

    begin {
        Write-Log -Message "Uninstalling $packageName..." -Severity 1
    } 
    
    process {           
        $argumentList = "uninstall $packageName --yes"
        
        $process = Start-Process choco -ArgumentList $argumentList -PassThru -Wait
        $exitCode = $process.exitCode

        Write-Log -Message "Exit code for $packageName`: $exitCode" -Severity 0

        if ($exitCode -eq 0) {
            Write-Log -Message "'$packageName' was successfully uninstalled." -Severity 1
            $ExitMessage = "-"
        } else {
            Write-Log -Message "An error occurred while uninstalling '$packageName'. Message: $($process.StandardError)" -Severity 3
            Write-Log -Message "$LastExitCode" -Severity 0
            $ExitMessage = $process.StandardError
        }
        
        return @{ExitCode = $exitCode; Message = $ExitMessage}
    } 
    
    end {
    }

}