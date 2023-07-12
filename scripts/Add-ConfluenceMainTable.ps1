function Add-ConfluenceMainTable {
    <#
    .SYNOPSIS
        This function alows a more generic way to create the needed HTML-table with all software-testing-results than it used to be
    .DESCRIPTION
        This function takes all information needed for creating a proper HTML-table to be uploaded to Confluence
    .NOTES
        FileName:    Create-ConfulenceMainTable.ps1
        Author:      Uwe Molnar
        Contact:     uwe.molnar@unibas.ch
        Created:     2023-07-12
        Updated:     -
        Version:     1.0.0
    .PARAMETER
        All information nested in the results-json-file, that is collection during a software-testing-run
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
