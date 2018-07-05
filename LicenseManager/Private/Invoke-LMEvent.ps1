<#
    .Synopsis
    
        This is the handler for each detected event (start/stop of watched process).

    .Parameter Action

        The action (Start Event or Stop Event) that we're watching for.
        This just makes it easier than eveluating the LMEvent parameter for this information.

    .Parameter LMEvent

        Event object of the event triggered by the starting or stopping of a watched process.

    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
#>
function Invoke-LMEvent {
    [CmdletBinding()]
    [OutputType([void])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Start', 'Stop')]
        [string]
        $Action,

        [Parameter(Mandatory = $true)]
        # [System.Management.Automation.PSEventArgs]
        $LMEvent,
        
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager
    )
    Write-Verbose "[Invoke-LMEvent] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Invoke-LMEvent] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
    
    <#
        The if statements are required for Pester testing.
    #>
    if (-not (Get-Command 'Add-LMEntry' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Add-LMEntry.ps1"
    }
    if (-not (Get-Command 'Assert-LMEntry' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Assert-LMEntry.ps1"
    }
    if (-not (Get-Command 'Deny-LMEntry' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Deny-LMEntry.ps1"
    }
    if (-not (Get-Command 'Remove-LMEntry' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Remove-LMEntry.ps1"
    }

    Write-Verbose "[Invoke-LMEvent] LMEvent: $($LMEvent | Out-String)"
    Write-Verbose "[Invoke-LMEvent] LMEvent SourceEventArgs: $($LMEvent.SourceEventArgs | Out-String)"
    Write-Verbose "[Invoke-LMEvent] LMEvent SourceEventArgs NewEvent All: $($LMEvent.SourceEventArgs.NewEvent | Select-Object * | Out-String)"
    Write-Verbose "[Invoke-LMEvent] LMEvent SourceEventArgs NewEvent CimInstanceProperties: $($LMEvent.SourceEventArgs.NewEvent.CimInstanceProperties | Select-Object * | Out-String)"
    
    $ProcessName = $LMEvent.SourceEventArgs.NewEvent.ProcessName
    Write-Verbose "[Invoke-LMEvent] ProcessName:  ${ProcessName}"
    $ProcessId = $LMEvent.SourceEventArgs.NewEvent.ProcessId
    Write-Verbose "[Invoke-LMEvent] ProcessId:  ${ProcessId}"

    if ($Action -eq 'Start') {
        $ProcessUserName = (Get-Process -Id $ProcessId -IncludeUserName).UserName
        Write-Verbose "[Invoke-LMEvent] ProcessUserName:  ${ProcessUserName}"
    } else {
        $ProcessUserName = $null
        Write-Verbose "[Invoke-LMEvent] ProcessUserName is UNAVAILABLE; Process Stopped."
    }
    
    $lmEntry = @{
        LicenseManager  = $LicenseManager
        ProcessName     = $ProcessName
        ProcessId       = $ProcessId
        ProcessUserName = $ProcessUserName
    }
    Write-Verbose "[Invoke-LMEvent] LM Entry: $($lmEntry | ConvertTo-Json)"
    
    Write-Verbose "[Invoke-LMEvent] Action: ${Action}"
    if ($Action -eq 'Start') {
        Write-Verbose "[Invoke-LMEvent] Action Start; Determine if Process is allowed to start."
        if (Assert-LMEntry @lmEntry) {
            Write-Verbose "[Invoke-LMEvent] Determined Process Allowed is TRUE; Adding Process entry to JSON."
            Add-LMEntry @lmEntry
        } else {
            Write-Verbose "[Invoke-LMEvent] Determined Process Allowed is FALSE; Deny user and kill process."
            Deny-LMEntry @lmEntry
        }
    } else { # Stop
        Write-Verbose "[Invoke-LMEvent] Action Stop; Removing Entry."
        Remove-LMEntry @lmEntry
    }
}