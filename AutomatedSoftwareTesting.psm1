$scripts = @(Get-ChildItem -Path $PSScriptRoot\scripts\*.ps1 -Recurse -ErrorAction SilentlyContinue)

foreach ($script in $scripts) {
    try {
        . $script.fullname
    }
    catch {
        Write-Error -Message "Failed to import script $($script.fullname): $_"
    }
}

Export-ModuleMember -Function $scripts.BaseName