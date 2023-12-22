function Test-HasNoDesktopShortcutForPublicUser () {
    <#
    .Synopsis
    Function to check if a package has NO desktop shortcut for the public user
    .DESCRIPTION
    Function to check if a package has NO desktop shortcut for the public user. Returns $true or $false
    .NOTES
    FileName:    Test-HasNoDesktopShortcutForPublicUser.ps1
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
        Write-Log -Message "Searching for Desktop-Shortcuts for '$packageName'..." -Severity 0
    } 
    
    process {           
        if ($packageName.StartsWith("unibas-")) {
            Write-Log -Message "Cutting of 'unibas-'-Prefix" -Severity 0
            $shortcutName = $packageName.Substring(7)
        } else {
            $shortcutName = $packageName
        }

        $shortcutNames = @(
            $shortcutName,
            (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like "*$packageName*"}).DisplayName,
            (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like "*$packageName*"}).DisplayName,
            (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like "*$packageName*"}).DisplayName,
            $originalName
        )

        foreach ($name in $shortcutNames) {
            # Check if $name is not empty (e.g. if no $originalName was found!)
            if ($name){
                $shortcutPath = "C:\Users\Public\Desktop\$name.lnk"

                if (Test-Path $shortcutPath) {
                    Write-Log -Message "Desktop-Shortcut for '$packageName' found!" -Severity 2
                    return $false
                }
    
            }
        }

        Write-Log -Message "No Desktop-Shortcut for '$packageName' found! Trying to be more aggressiv..." -Severity 0

        $DesktopShortcuts = (Get-ChildItem -Path "C:\Users\Public\Desktop\" -Filter "*.lnk").Name
        $DesktopShortcutsCount = (Get-ChildItem -Path "C:\Users\Public\Desktop\" -Filter "*.lnk").Length
        
        if ($DesktopShortcutsCount -ne 0){
            Write-Log -Message "Some Desktop-Shortcut found!" -Severity 2
            return $false, $DesktopShortcuts
        } else { 
            Write-Log -Message "No Desktop-Shortcuts found at all!" -Severity 1
            return $true
        }
    } 
    
    end {
    }

}