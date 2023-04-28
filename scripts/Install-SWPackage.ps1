function Install-SWPackage {
    <#
    .Synopsis
    Function to install a package update via Chocolatey and return the exit code and message
    .DESCRIPTION
    Function to install a package update via Chocolatey and return the exit code and message
    .NOTES
    FileName:    Install-PackageUpdate.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-04-17
    Updated:     -
    Version:     1.0.0
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$packageName,

        [Parameter()]
        [switch]$update
    )

    begin {
        # Check if the script is used to install an update for the software-package or raw-install the software-package
        if ($update){
            Write-Log -Message "Installing update for '$packageName'..." -Severity 0
        } else {
            Write-Log -Message "Installing '$packageName'..." -Severity 0
        }
        $argumentList = "upgrade $packageName --yes --force"
    } 
    
    process {
        $process = Start-Process choco -ArgumentList $argumentList -PassThru -Wait
        $exitCode = $process.exitCode
        
        if ($exitCode -eq 0) {
            if ($update){
                Write-Log -Message "'$packageName' successfully updated." -Severity 1
            } else {
                Write-Log -Message "'$packageName' successfully installed." -Severity 1
            }
            $ExitMessage = "-"

        } else {
            $ExitMessage = Search-ChocoLogFile -package $packageName

            if ($update){
                Write-Log -Message "An error occurred while updating '$packageName'. Exit-Code: $exitCode" -Severity 3
                Write-Log -Message "Exit-Message: $ExitMessage" -Severity 3
            } else {
                Write-Log -Message "An error occurred while installing '$packageName'. Exit-Code: $exitCode" -Severity 3
                Write-Log -Message "Exit-Message: $ExitMessage" -Severity 3
            }
        }

        return @{ExitCode = $exitCode; Message = $exitMessage} 
    }
    
    end{
    }
}