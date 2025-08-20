function Get-ExcludedPackages () {
    <#
    .Synopsis
    Gets the list of packages and tests that should be excluded from testing
    .DESCRIPTION
    Reads an exclusion file (similar to wishlist) to determine which packages should skip certain tests.
    Format: PackageName:TestType (e.g., "msedge:uninstall" or "firefox:all")
    .NOTES
    FileName:    Get-ExcludedPackages.ps1
    Author:      Max Marllon Mendes Carvalho
    Contact:     m.mendescarvalho@unibas.ch
    Created:     2025-08-20
    Updated:     -
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$exclusionFilePath
    )

    begin {
        if (-not $exclusionFilePath) {
            $config = Read-ConfigFile
            $exclusionFilePath = $config.Application.ExclusionListPath
            if (-not $exclusionFilePath) {
                $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
                $exclusionFilePath = Join-Path -Path $rootPath -ChildPath "excluded-packages.txt"
            }
        }
        $exclusions = @{}
    } 
    
    process {          
        # Check if exclusion file exists
        if (Test-Path -Path $exclusionFilePath) {
            Write-Log -Message "Reading exclusion file: $exclusionFilePath" -Severity 0
            
            $exclusionLines = Get-Content -Path $exclusionFilePath | Where-Object { 
                $_.Trim() -ne "" -and -not $_.StartsWith("#") 
            }
            
            foreach ($line in $exclusionLines) {
                $line = $line.Trim()
                if ($line -match "^(.+):(.+)$") {
                    $packageName = $Matches[1].Trim().ToLower()
                    $testType = $Matches[2].Trim().ToLower()
                    
                    if (-not $exclusions.ContainsKey($packageName)) {
                        $exclusions[$packageName] = @()
                    }
                    $exclusions[$packageName] += $testType
                    
                    Write-Log -Message "Exclusion added: $packageName -> $testType" -Severity 0
                } elseif ($line -ne "") {
                    Write-Log -Message "Invalid exclusion format: $line (use PackageName:TestType)" -Severity 2
                }
            }
        } else {
            Write-Log -Message "Exclusion file not found: $exclusionFilePath. No packages will be excluded." -Severity 0
        }
    } 
    
    end {
        if ($exclusions.Count -gt 0) {
            Write-Log -Message "Total exclusions loaded: $($exclusions.Count) packages" -Severity 0
        }
        return $exclusions
    }
    
}