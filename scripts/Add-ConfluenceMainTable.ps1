function Add-ConfluenceMainTable {
    <#
    .SYNOPSIS
        This function
    .DESCRIPTION
        
    .NOTES
        FileName:    Create-ConfulenceMainTable.ps1
        Author:      Uwe Molnar
        Contact:     uwe.molnar@unibas.ch
        Created:     2023-07-12
        Updated:     -
        Version:     1.0.0

    .PARAMETER
        
    .EXAMPLE
        
    #>
    param (
        $PackageName,
        $InstalledVersion,
        $LatestVersion,
        $UpdateExitCode,
        $UpdateExitMessage,
        $HasNoDesktopShortcutForPublicUser,
        $HasNotMultipleAddRemoveEntries,
        $Dependencies,
        $UninstallDependenciesExitCode,
        $UninstallDependenciesExitMessage,
        $UninstallExitCode,
        $UninstallExitMessage,
        $InstallExitCode,
        $InstallExitMessage,
        $color
    )

    begin {
    }

    process {
        return @"
        <tr>
        <td style='background-color: $color'>$($packageName)</td>
        <td style='background-color: $color'>$($InstalledVersion)</td>
        <td style='background-color: $color'>$($LatestVersion)</td>
        <td style='background-color: $color'>$($UpdateExitCode)</td>
        <td style='background-color: $color'>$($UpdateExitMessage)</td>
        <td style='background-color: $color'>$($HasNoDesktopShortcutForPublicUser)</td>
        <td style='background-color: $color'>$($HasNotMultipleAddRemoveEntries)</td>
        <td style='background-color: $color'>$($Dependencies)</td>
        <td style='background-color: $color'>$($UninstallDependenciesExitCode)</td>
        <td style='background-color: $color'>$($UninstallDependenciesExitMessage)</td>
        <td style='background-color: $color'>$($UninstallExitCode)</td>
        <td style='background-color: $color'>$($UninstallExitMessage)</td>
        <td style='background-color: $color'>$($InstallExitCode)</td>
        <td style='background-color: $color'>$($InstallExitMessage)</td>
        </tr>
"@
    }

    end{
    }
}