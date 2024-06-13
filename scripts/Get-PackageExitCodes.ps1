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
        $global:patternInstaller = "(?i)^(\s*)(fileType)(\s*)(=)(\s*)(['""])(.*)(['""])$"
        $patternExitCodes = "(?i)^(\s*)(validExitCodes)(\s*)(=)(\s*)(@\()(.*)(\))$"
    } 
    
    process {          
        function CheckInstallerType ([string]$PathToChocolateyInstallFile) {
            $installer = Get-Content -Path $PathToChocolateyInstallFile | Select-String -Pattern $global:patternInstaller

            $null = $installer -match $global:patternInstaller
            if ($Matches[7] -like "msi") {
                $ExitCodes = @("0", "1614", "1641", "3010")
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
            # Check for validExitCodes in the chocolateyInstall.ps
            $exitCodeLine = Get-Content -Path $chocoInstallPath | Select-String -Pattern $patternExitCodes 
            
            if ($exitCodeLine) {
                $null = $exitCodeLine -match $patternExitCodes
                $validExitCodes += ($Matches[7] -split ",")
            } else {
                $validExitCodes = CheckInstallerType $chocoInstallPath
            }
        }
    } 
    
    end {
        return $validExitCodes
    }
    
}