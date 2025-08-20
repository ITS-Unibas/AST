function Get-PackageExitCodes () {
    <#
    .Synopsis
    Gets the valid exit-codes fora given package or returns the default ones
    .DESCRIPTION
    Gets the valid exit-codes fora given package or returns the default ones; e.g. valid Exit-Codes for MSI-Installer  
    .NOTES
    FileName:    Get-PackageExitCodes.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2024-06-12
    Updated:     -
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$packageName,

        [Parameter(Mandatory = $false)]
        [switch]$uninstall
    )

    begin {
        $chocoSuccessfulInstallPath = Join-Path $env:ChocolateyInstall "lib"
        $chocoUnsuccessfulInstallPath = Join-Path $env:ChocolateyInstall "lib-bad"
        $chocolateyInstallFile = "chocolateyInstall.ps1"        
        $validExitCodes = @()
        $global:patternInstaller = "(?i)(fileType)(\s*)(=)(\s*)(['""])(.*)(['""])"
        $patternExitCodes = "(?i)(validExitCodes)(\s*)(=)(\s*)(@\()(.*)(\))"
    } 
    
    process {          
        function CheckInstallerType ([string]$PathToChocolateyInstallFile) {
            $installer = Get-Content -Path $PathToChocolateyInstallFile | Select-String -Pattern $global:patternInstaller

            if ($installer -match $global:patternInstaller){
                if ($Matches[6] -like "msi") {
                    $ExitCodes = @("0", "1614", "1641", "3010")
                } else {
                    $ExitCodes = @("0")
                }
            } else {
                $ExitCodes = @("0")
            }           
            return $ExitCodes
        }
        
        $chocoInstallPath = ""  
        # Check if the package was installed successfully or unsuccessfully
        if (Test-Path -Path "$chocoSuccessfulInstallPath\$packageName") {
            $chocoInstallPath = Join-Path $chocoSuccessfulInstallPath "$($packageName)\tools\$($chocolateyInstallFile)"
        } elseif (Test-Path -Path "$chocoUnsuccessfulInstallPath\$packageName") {
            $chocoInstallPath = Join-Path $chocoUnsuccessfulInstallPath "$($packageName)\tools\$($chocolateyInstallFile)"
        }

        # Check if uninstall is requested
        if ($uninstall) {
            $validExitCodes = CheckInstallerType $chocoInstallPath
        } else {
            # Check for validExitCodes in the chocolateyInstall.ps1 file
            if (Test-Path $chocoInstallPath) {
                Write-Log -Message "Looking for validExitCodes in: $chocoInstallPath" -Severity 0
                $exitCodeLine = Get-Content -Path $chocoInstallPath | Select-String -Pattern $patternExitCodes 
                
                if ($exitCodeLine) {
                    Write-Log -Message "Found validExitCodes line: $exitCodeLine" -Severity 0
                    $null = $exitCodeLine -match $patternExitCodes
                    # Extract the exit codes from group 6 and clean them up
                    $exitCodesString = $Matches[6]
                    $validExitCodes += ($exitCodesString -split "," | ForEach-Object { $_.Trim() -replace "[^0-9]", "" } | Where-Object { $_ -ne "" })
                    Write-Log -Message "Extracted validExitCodes: $($validExitCodes -join ', ')" -Severity 0
                } else {
                    Write-Log -Message "No validExitCodes found in chocolateyInstall.ps1, using installer type defaults" -Severity 0
                    $validExitCodes = CheckInstallerType $chocoInstallPath
                }
            } else {
                Write-Log -Message "chocolateyInstall.ps1 not found at: $chocoInstallPath" -Severity 1
                $validExitCodes = @("0")
            }
        }
    } 
    
    end {
        return $validExitCodes
    }
    
}