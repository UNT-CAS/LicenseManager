#Requires -RunAsAdministrator
<#
    .Synopsis

        This is the MAIN script. This script watches for events and sends found events to Invoke-LMEvent for handling.

    .Parameter LicenseManager

        A JSON hashtable of processes to concurrency maximum.

        Example: '{"DirectoryPath":"\\\\license\\LicenseManager","Processes":{"notepad.exe":5,"Calculator.exe":10}}'

        Done this way so we can use the default of setting this as an Environment Variable for the system. Here's the example, but a little easier to read:

            {
                "DirectoryPath":  "\\\\license\\LicenseManager",
                "Processes":  {
                                "notepad.exe":  5,
                                "Calculator.exe":  10
                            }
            }

        The number with the process name is the concurrency count.
#>
function Invoke-LicenseManager {
    [CmdletBinding()]
    [OutputType([void])]
    Param(
        [Parameter()]
        [string]
        $LicenseManager = $env:LicenseManager,
        
        [Parameter()]
        [switch]
        $Force
    )
    Write-Verbose "[LicenseManager] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[LicenseManager] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
    
    if ($Force.IsPresent) {
        Write-Verbose "[LicenseManager] Skipping Duplicate Process Check."
    } else {
        if ($proc = Get-WmiObject Win32_Process -Filter "Name = ""powershell.exe"" AND ProcessId <> ""${PID}""" | Where-Object { $_.CommandLine -like '*Invoke-LicenseManager*' }) {
            Write-Warning "Duplicate process(es) found: $($proc.ProcessId -join ', ')"
            $proc | ForEach-Object { Write-Verbose "[LicenseManager] $($_.ProcessId): $($_.CommandLine)" }
            Exit 1
        }
    }

    $psScriptRootParent = Split-Path $PSScriptRoot -Parent

    if (-not $LicenseManager) {
        Throw [System.Management.Automation.ParameterBindingException] 'Required Parameter (LicenseManager) is not available.'
    }
    $LicenseManager = $LicenseManager | ConvertFrom-Json

    $jobScriptBlock = {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $Action,

            [Parameter(Mandatory = $true)]
            [IO.DirectoryInfo]
            $ScriptRoot,

            [Parameter(Mandatory = $true)]
            [array]
            $LicenseManager
        )
        . "${ScriptRoot}\Private\Invoke-LMEvent.ps1"

        $processes = $LicenseManager.Processes.PSObject.Properties.Name | ForEach-Object { "ProcessName = '${_}'" }
        $processQuery = "SELECT * FROM Win32_Process${Action}Trace WHERE $($Processes -join ' OR ')"

        $SourceIdentifier = "LicenseManager_Process${Action}_$(New-Guid)"
        Register-CimIndicationEvent -Query $processQuery -SourceIdentifier $SourceIdentifier

        while ($true) {
            $lmEvent = Wait-Event -SourceIdentifier $SourceIdentifier
            Write-Verbose "[LicenseManager] LM ${Action} Event: $($lmEvent | Out-String)"

            Remove-Event -EventIdentifier $lmEvent.EventIdentifier

            Invoke-LMEvent -Action $Action -LicenseManager $LicenseManager -LMEvent $lmEvent -Verbose
        }
    }

    <#
        Check for currently running processes a get them added.
        This should really only be needed if the script is being restarted, but let's cover our basis.
    #>
    Write-Verbose "[LicenseManager] Intializing ..."
    . "${psScriptRootParent}\Private\Initialize-LMEntry.ps1"

    foreach ($process in $LicenseManager.Processes.PSObject.Properties.Name) {
        Write-Verbose "[LicenseManager] Initializing Process: ${process}"
        [IO.FileInfo] $process = $process

        $lmEntry = @{
            LicenseManager = $LicenseManager
            ProcessName    = $process.Name
        }
        Write-Verbose "[LicenseManager] Initialize-LMEntry: $($lmEntry | ConvertTo-Json)"
        Initialize-LMEntry @lmEntry
    }

    <#
        Start the Background Job to watch for Processes STARTING.
    #>
    $jobProcessStart = Start-Job -Name 'LM_ProcStart' -ScriptBlock $jobScriptBlock -ArgumentList 'Start', $psScriptRootParent, $LicenseManager
    Write-Verbose "[LicenseManager] Started Job: LM_ProcStart (${jobProcessStart})"

    <#
        Start the Background Job to watch for Processes STOPPING
    #>
    $jobProcessStop = Start-Job -Name 'LM_ProcStop' -ScriptBlock $jobScriptBlock -ArgumentList 'Stop', $psScriptRootParent, $LicenseManager
    Write-Verbose "[LicenseManager] Started Job: LM_ProcStop (${jobProcessStop})"

    <#
        This is here while developing.
        Comment this little bit out before going to production.
    #>
    # Write-Verbose "[LicenseManager] Running notepad in 3 second ..."
    # Start-Sleep -Seconds 3
    # notepad

    <#
        Keep this Process Open; k thanks
    #>
    while ($true) {
        $jobProcessStart | Receive-Job
        $jobProcessStop | Receive-Job
        Start-Sleep -Seconds 1
    }
}
