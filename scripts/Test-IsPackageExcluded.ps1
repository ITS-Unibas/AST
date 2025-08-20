function Test-IsPackageExcluded () {
    <#
    .Synopsis
    Checks if a specific test should be excluded for a given package
    .DESCRIPTION
    Determines whether a specific test (update, uninstall, install, desktop, appwiz, all) 
    should be skipped for the given package based on the exclusion configuration.
    .NOTES
    FileName:    Test-IsPackageExcluded.ps1
    Author:      Max Marllon Mendes Carvalho
    Contact:     m.mendescarvalho@unibas.ch
    Created:     2025-08-20
    Updated:     -
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$packageName,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("update", "uninstall", "install", "desktop", "appwiz", "all")]
        [String]$testType,
        
        [Parameter(Mandatory = $true)]
        [Hashtable]$exclusions
    )

    begin {
        $packageNameLower = $packageName.ToLower()
        $testTypeLower = $testType.ToLower()
    } 
    
    process {          
        # Check if package has any exclusions
        if ($exclusions.ContainsKey($packageNameLower)) {
            $packageExclusions = $exclusions[$packageNameLower]
            
            # Check for "all" exclusion (skip entire package)
            if ("all" -in $packageExclusions) {
                Write-Log -Message "Package '$packageName' excluded from ALL tests" -Severity 1
                return $true
            }
            
            # Check for specific test exclusion
            if ($testTypeLower -in $packageExclusions) {
                Write-Log -Message "Package '$packageName' excluded from '$testType' test" -Severity 1
                return $true
            }
        }
        
        return $false
    } 
    
    end {
        # Nothing to return in end block
    }
    
}