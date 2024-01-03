function Add-NewPackagesForTesting () {
    <#
    .Synopsis
    Adds new software-packages to be tested by AST
    .DESCRIPTION
    Adds new software-packages to be tested by AST that are included in the "add-packages.txt"-file from an external repository.   
    .NOTES
    FileName:    Add-NewPackagesForTesting.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-12-27
    Updated:     2024-01-03
    Version:     1.2.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$wishlist
    )

    # Check if the "ast-wishlist" exists
    if (-not (Test-Path -Path $wishlist)) {
        Write-Log -Message "AST Wishlist '$wishlist' does not exist or is misconfigured. Please create it or check the config-file." -Severity 3
        return
    } 
        
    # Get the contents of the "ast-wishlist"						  
    Write-Log -Message "Searching for new software-package(s) that were added manually to AST in the AST wishlist..." -Severity 1

    # Get the latest AST wishlist from GitHub or another external repository
    $wishListPath = (Get-Item -Path $wishlist).DirectoryName
    $wishlistFile = (Get-Item -Path $wishlist).Name
    try {
        Write-Log -Message ([string] (git -C $wishListPath checkout main 2>&1)) -Severity 1
        Write-Log -Message ([string] (git -C $wishListPath pull origin main 2>&1)) -Severity 1
    }
    catch {
        Write-Log -Message "Something went wrong while checking out or pulling AST wishlist! Skip AST wishlist for this time. Encountered Error: $($_.Exception.Message)" -Severity 3
        return
    }

    # Get the contents of the wishlist and scan for new packages
    $newPackagesToBeAdded = Get-Content -Path $wishlist | Where-Object {$_.Trim() -ne '' -and $_ -notmatch '^#' -and $_ -notmatch '\|'}
    
    $manuallyAddedPackages = New-Object System.Collections.ArrayList

    if ($newPackagesToBeAdded){
        # Check if
        # + the new added packages exist on the repo and 
        # + if they are note already installed and
        # Afterwards set a date- and time-stamp for the new packages to be ignored by AST in the next run(s)
        $newPackagesToBeAdded | ForEach-Object {
            $newPackage = $_
            # Check if the new added packages exist on the repo or is already installed
            $newPackageCheckOnRepo = (choco search $newPackage --source dev -r)
            $newPackageCheckInstall = (choco list -lo $newPackage -r)

            if ($newPackageCheckOnRepo -and !($newPackageCheckInstall)){
                Write-Log -Message "Checking software-package: '$newPackage' OK! $newPackage not installed and found on dev-Repo!" -Severity 1
                $manuallyAddedPackages.Add($newPackage)
                # Edit the add-packages-list
                $newPackageEdited = $newPackage + " | " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                $null = (Get-Content -Path $wishlist) -replace "^$newPackage\n|^$newPackage$", $newPackageEdited | Set-Content -Path $wishlist
            } else {
                Write-Log -Message "Checking software-package: '$newPackage' NOT OK! $newPackage NOT found on dev-Repo or already installed! Skipping $newPackage." -Severity 2
                $newPackageEdited = $newPackage + " | " + "IGNORED: Package not found on dev-Repo or already installed!"
                $null = (Get-Content -Path $wishlist) -replace "^$newPackage\n|^$newPackage$", $newPackageEdited | Set-Content -Path $wishlist
            }
        }
        
        # Sort the added packages in the add-packages-file alphabetically
        $header = Get-Content -Path $wishlist | Where-Object {$_ -match '^#'}
        $body = Get-Content -Path $wishlist | Where-Object {$_ -notmatch '^#'} | Sort-Object
        Set-Content -Value ($header + $body) -Path $wishlist 

        # Push changes to GitHub or another external repository
        try {
            Write-Log -Message ([string] (git -C $wishListPath add $wishlistFile 2>&1)) -Severity 1
            Write-Log -Message ([string] (git -C $wishListPath commit -m "Automated update of AST-Wishlist" 2>&1)) -Severity 1
            Write-Log -Message ([string] (git -C $wishListPath push 2>&1)) -Severity 1               
        }
        catch {
            Write-Log -Message "Something went wrong while updating and pushing AST wishlist! Encountered Error: $($_.Exception.Message)" -Severity 3
        }

        # Setup all new packages
        $newPackagesToBeAddedCompleted = $manuallyAddedPackages | ForEach-Object {
            $packageName = $_
            $installedVersion = "0.0"
            $latestVersion = (choco search $packageName --source dev -r).split("|")[1]
            [PSCustomObject]@{
                PackageName = $packageName
                InstalledVersion = $installedVersion
                LatestVersion = $latestVersion
            }
        }

        $allManuallyAddedPackages = New-Object System.Collections.ArrayList

        # Add all packages together
        foreach ($package in $newPackagesToBeAddedCompleted){
            $allManuallyAddedPackages.Add($package)
        }   

    } else {
        Write-Log -Message "No new software-package(s) found to be tested by AST." -Severity 1
    }

    return  @{packages = $allManuallyAddedPackages}
}