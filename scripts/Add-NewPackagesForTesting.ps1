function Add-NewPackagesForTesting () {
    <#
    .Synopsis
    Adds new software-packages to be tested by AST
    .DESCRIPTION
    Adds new software-packages to be tested by AST that are included in the "add-packages.txt"-file    
    .NOTES
    FileName:    Add-NewPackagesForTesting.ps1
    Author:      Uwe Molnar
    Contact:     uwe.molnar@unibas.ch
    Created:     2023-12-27
    Updated:     2023-12-28
    Version:     1.1.0
    #>

    begin {
        # Check if the "add-packages.txt"-file exists
        $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
        $addPackagesListFile = "add-packages.txt"
        $addPackagesListFilePath = Join-Path -Path $rootPath -ChildPath $addPackagesListFile

        if (-not (Test-Path -Path $addPackagesListFilePath)) {
            Write-Log -Message "The file '$addPackagesListFile' does not exist. Please create it and add the packages you want to be tested by AST." -Severity 3
            return
        } 
    } 
    
    process {           
        # Get the contents of the "add-packages.txt"-file
        # TBD: Include GIT
        Write-Log -Message "Searching for new software-package(s) that were added manually to AST..." -Severity 1

        $addPackagesListFilePath = "C:\ProgramData\AST\add-packages.txt"
        $newPackagesToBeAdded = Get-Content -Path $addPackagesListFilePath | Where-Object {$_.Trim() -ne '' -and $_ -notmatch '^#' -and $_ -notmatch '\|'}
        
        $manuallyAddedPackages = New-Object System.Collections.ArrayList

        if ($newPackagesToBeAdded){
            Write-Log -Message "New software-package(s) found to be tested by AST: `n $newPackagesToBeAdded" -Severity 1

            # Check if the new added packages exist on the repo and if they are note already installed and set a date- and time-stamp for the new packages to be ignored by AST in the next run(s)
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
                    $null = (Get-Content -Path $addPackagesListFilePath) -replace "^$newPackage\n|^$newPackage$", $newPackageEdited | Set-Content -Path $addPackagesListFilePath
                } else {
                    Write-Log -Message "Checking software-package: '$newPackage' NOT OK! $newPackage NOT found on dev-Repo or already installed! Skipping $newPackage." -Severity 2
                    $newPackageEdited = $newPackage + " | " + "IGNORED: Package not found on dev-Repo or already installed!"
                    $null = (Get-Content -Path $addPackagesListFilePath) -replace "^$newPackage\n|^$newPackage$", $newPackageEdited | Set-Content -Path $addPackagesListFilePath
                }
            }
            
            # Sort the added packages in the add-packages-file alphabetically
            $header = Get-Content -Path $addPackagesListFilePath | Where-Object {$_ -match '^#'}
            $body = Get-Content -Path $addPackagesListFilePath | Where-Object {$_ -notmatch '^#'} | Sort-Object
            Set-Content -Value ($header + $body) -Path $addPackagesListFilePath 
            
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
    }

    end {
        return  @{packages = $allManuallyAddedPackages}
    }
}