function Write-Log {
    <#
    .SYNOPSIS
        Writes a message in a log file.
    .DESCRIPTION
        If the Write-Log function is called the given string is logged into a log file. The log file folder is created if non-existing and there will be a maximum number of log files.
        If the max number of log files is reached the oldest one gets removed.
    .NOTES
        FileName:    Write-Log.ps1
        Author:      Maximilian Burgert, Tim Koenigl, Kevin Schaefer, Uwe Molnar
        Contact:     its-wcs-ma@unibas.ch
        Created:     2019-07-30
        Updated:     2023-04-14
        Version:     1.1.0
    .PARAMETER Message
        The message which gets logged as a string.
    .PARAMETER Severity
        The log level. There are 3 log levels (1,2,3) where 0 is the lowest and 3 the highest log level.
    .EXAMPLE
        PS> Write-Log -Message "TestLog" -Severity 2
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('0', '1', '2', '3')]
        [ValidateNotNull()]
        [int]$Severity = 0 # Default
    )
    begin {
        $Config = Read-ConfigFile
        $rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
        $LogPath = Join-Path -Path $rootPath -ChildPath $Config.Logging.LogPath
        $MaxLogFiles = $Config.Logging.MaxLogFiles
        $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Config.Logging.LogFileNamePrefix)_$(Get-Date -Format yyyyMMdd).log"

    } process {

        if ($Message -eq "") {
            return
        }

        switch ($Severity) {
            0 {
                $EntryType = "Debug"
                $ForegroundColor = "Cyan"
            }
            1 {
                $EntryType = "Information"
                $ForegroundColor = "Magenta"
            }
            2 {
                $EntryType = "Warning"
                $ForegroundColor = "Yellow"
            }
            3 {
                $EntryType = "Error"
                $ForegroundColor = "Red"
            }
            Default {
                $ForegroundColor = "White"
            }
        }

        $line = "$(Get-Date -Format 'dd/MM/yyyy HH:mm') $($EntryType) $((Get-PSCallStack)[1].Command): $($Message)"

        # Create LogFileFolder and LogFile if not available
        if (-Not (Test-Path $LogPath -ErrorAction SilentlyContinue)) {
            $null = New-Item -ItemType directory -Path $LogPath
        }

        if (-Not (Test-Path $LogFilePath -ErrorAction SilentlyContinue)) {
            $numLogFiles = (Get-ChildItem -Path $LogPath -Filter '*.log' | Measure-Object).Count
            if ($numLogFiles -eq $MaxLogFiles) {
                Get-ChildItem $LogPath | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item
            }
            elseif ($numLogFiles -gt $MaxLogFiles) {
                Get-ChildItem $LogPath | Sort-Object CreationTime | Select-Object -First ($numLogFiles - $MaxLogFiles + 1) | Remove-Item
            }
            $null = New-Item $LogFilePath -type file
        }

        $line | Out-File $LogFilePath -Append

        # Write log to host
        Write-Host $line -ForegroundColor $ForegroundColor
    }
}