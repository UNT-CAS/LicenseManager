<#
    .Synopsis

        This script determines if the current process is allowed to run.

    .Description

        This script determines if the current process is allowed to run by checking if the number of entries is less than the concurrency limit defined in the LicenseManager parameter.
        If it already at the at the concurrency limit, it will allow the same user on the same computer to run multiple of the same processes.
    
    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
    
    .Parameter ProcessName

        The name of the Process, with the extension.

    .Parameter ProcesssId

        The Process ID of the currently running Process.

    .Parameter ProcesssUserName

        The UserName of the user running the aforementioned Process ID.
#>
function Assert-LMEntry {
    [CmdleBinding()]
    [OutputType([bool])]
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
    Write-Verbose "[Assert-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Assert-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    [IO.FileInfo] $jsonFilePath = "$($LicenseManager.DirectoryPath)\${ProcessName}.json"
    Write-Verbose "[Asset-LMEntry] JSON File: ${jsonFilePath}"
    
    if (-not (Test-Path $jsonFilePath)) {
        Write-Verbose "[Asset-LMEntry] JSON file doesn't exist, so there are no entries. I guess we're allowed!"
        return $true
    }

    $jsonInfo = Get-Content -LiteralPath $jsonFilePath | Out-String | ConvertFrom-Json
    $jsonInfoCount = ($jsonInfo | Measure-Object).Count
    $ProcessConcurrentMax = $LicenseManager.Processes.$ProcessName
    Write-Verbose "[Asset-LMEntry] JSON Info Count: ${jsonInfoCount}"
    Write-Verbose "[Asset-LMEntry] Process Concurrent Max: ${ProcessConcurrentMax}"
    if ($jsonInfoCount -lt $ProcessConcurrentMax) {
        Write-Verbose "[Asset-LMEntry] JSON Info Count is LESS THAN the Process Concurrent Max. I guess we're allowed!"
        return $true
    }

    $relevantJsonInfo = $jsonInfo | Where-Object { ($currentJsonInfo.ComputerName -eq $env:COMPUTERNAME) -and ($currentJsonInfo.UserName -eq $ProcessUserName) }
    Write-Verbose "[Asset-LMEntry] Relevant JSON Info: $($relevantJsonInfo | Out-String)"
    if ($relevantJsonInfo) {
        Write-Verbose "[Asset-LMEntry] Found Relvant JSON Info. I guess we're allowed!"
        return $true
    }

    Write-Verbose "[Asset-LMEntry] NO CONDITIONS PASSED. I guess we're NOT allowed!"
    return $false
}