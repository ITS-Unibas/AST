function Read-ConfigFile () {
    <#
    .Synopsis
    Read the configuration file
    .DESCRIPTION
    Read the configuration file
    .NOTES
    FileName:    Read-ConfigFile.ps1
    Author:      Kevin Schäfer
    Contact:     kevin.schaefer@unibas.ch
    Created:     2019-07-30
    Updated:     2019-07-30
    Version:     1.0.0
    #>
    [CmdletBinding()]
    param(
    )

    begin {

    } process {
        $FilePath = Join-Path -Path (Get-Item -Path $PSScriptRoot).Parent.FullName -ChildPath 'config.json'

        try {
            $Config = Get-Content -Path $FilePath | ConvertFrom-Json -ErrorAction Stop

        }
        catch {
            Write-Log $_.Exception -Severity 3
        }
    } end {
        return $config
    }

}