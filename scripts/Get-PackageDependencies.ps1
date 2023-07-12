function Get-PackageDependencies () {
    <#
    .Synopsis
    Gets all dependencies for a certain package
    .DESCRIPTION
    Gets all dependencies for a certain package via search in the nuspec-Files and returns them as an array
    .NOTES
    FileName:    Get-PackageDependencies.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-07-11
    Updated:     2023-07-11
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$packageName
    )

    begin {
        $chocoLibPath = Join-Path $env:ChocolateyInstall "lib" 
        $dependencyList = New-Object System.Collections.ArrayList
    } 
    
    process {       
        foreach ($nuspec in (Get-ChildItem $chocoLibPath -Recurse "*.nuspec")) {
            $metadata = ([xml](Get-Content $nuspec.Fullname)).package.metadata
            foreach ($dependency in $metadata.dependencies.dependency) { 
                if ($dependency.id -eq $packageName) {
                    $null = $dependencyList.Add($metadata.id) # $null is necessary because otherwise the dependecyList would contain a leading 0
                }                
            }
        }
        
        if ($dependencyList.Count -eq 0) {
            return "-"
        } else {
            return $dependencyList
        }
    } 
    
    end {
    }

}