<#
    .Synopsis

        This script creates or appends to a CSV that stores the log information of every denial.

    .Description

        This script creates or appends to a CSV that stores the log information of every denial.
        If the file doesn't exist, it will be created.
        If the file exists, it will be appended to.
    
    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
    
    .Parameter ProcessName

        The name of the Process, with the extension.

    .Parameter ProcesssId

        The Process ID of the currently running Process.

    .Parameter ProcesssUserName

        The UserName of the user running the aforementioned Process ID.
#>
function Write-LMEntryDenial {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager,

        [Parameter(Mandatory = $true)]
        [IO.FileInfo]
        $ProcessName,

        [Parameter(Mandatory = $true)]
        [int32]
        $ProcessId,

        [Parameter()]
        [string]
        $ProcessUserName
    )
    Write-Verbose "[Write-LMEntryDenial] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Write-LMEntryDenial] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    $csvPath = '{0}\{1}.csv' -f $LicenseManager.DirectoryPath, $ProcessName
    Write-Verbose "[Write-LMEntryDenial] CSV Path: ${csvPath}"
    
    $csvEntry = @{
        ProcessName      = $ProcessName
        ComputerName     = $env:COMPUTERNAME
        ProcessId        = $ProcessId
        ProcesssUserName = $ProcessUserName
        Timestamp        = (Get-Date -Format 'O')
    }
    Write-Verbose "[Write-LMEntryDenial] CSV Entry: $($csvEntry | ConvertTo-Json)"
    
    New-Object PSObject -Property $csvEntry | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Append -Force
    Write-Warning "[Write-LMEntryDenial] CSV Entry Added."
}