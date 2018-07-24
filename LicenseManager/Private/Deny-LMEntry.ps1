<#
    .Synopsis

        This script will kill a process and alert the user that concurrent usage has exceeded.

    .Description

        This script will deny the user from using the program/process by:
        - Alerting the user that concurrent usage has exceeded.
        - Killing the running process.

    .Parameter LicenseManager

        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.

    .Parameter ProcessName

        The name of the Process, with the extension.

    .Parameter ProcesssId

        The Process ID of the currently running Process.

    .Parameter ProcesssUserName

        The UserName of the user running the aforementioned Process ID.
#>
function Deny-LMEntry {
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
    Write-Verbose "[Deny-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Deny-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    <#
        .Synopsis

            Run a command as another user on the system.

        .Parameter User

            The user to run the command as.

        .Parameter Command

            The command to run.

        .Parameter IsVBSript

            If the command passed it VBScript, specify this switch. Otherwise, PowerShell is assumed.

        .Parameter Wait

            Wait for command to finish running before continuing. Even if this isn't set, we will wait until the command starts before continuing.
    #>
    function private:Invoke-AsUser {
        [CmdletBinding()]
        [OutputType([void])]
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $User,

            [Parameter(Mandatory = $true)]
            [string]
            $Command,

            [Parameter()]
            [switch]
            $IsVBScript,

            [Parameter()]
            [switch]
            $Wait
        )
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
        $scheduledTaskName = "LicenseManager-$(New-Guid)"

        if ($IsVBScript.IsPresent) {
            $vbscript = $Command
        } else {
            $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
            $vbscript = @'
Dim objShell
Set objShell = WScript.CreateObject("WScript.Shell")
objShell.Run """{0}"" {1}", 0
'@
            $vbscript = $vbscript -f @(
                (Get-Command 'powershell').Source,
                "-NonInteractive -ExecutionPolicy ByPass -EncodedCommand ${encodedCommand}"
            )
        }

        $vbscriptFile = New-TemporaryFile

        # Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Fixing Permissions on VBS/TMP file."
        # $acl = Get-Acl $vbscriptFile
        # $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'Read', 'Allow')
        # $acl.SetAccessRule($accessRule)
        # Set-Acl $vbscriptFile $acl

        # & icacls $vbscriptFile /grant:r "Everyone":(OI)(CI)M

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Moving VBS/TMP file."
        Move-Item -LiteralPath $vbscriptFile -Destination $env:SystemDrive -Force -Verbose
        $vbscriptFile = "$env:SystemDrive\$($vbscriptFile.Name)"

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Writing VBS (${vbscriptFile}): $($vbscript | Out-String)"
        $vbscript | Out-File -Encoding 'ascii' $vbscriptFile -Force

        $newScheduledTaskAction = @{
            'Execute'  = (Get-Command 'wscript').Source;
            'Argument' = "//NoLogo //E:vbscript ${vbscriptFile}";
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) New-ScheduledTaskAction: $($newScheduledTaskAction | Out-String)"

        $newScheduledTask = @{
            'Action'    = (New-ScheduledTaskAction @newScheduledTaskAction);
            'Principal' = (New-ScheduledTaskPrincipal -UserId $user);
            'Settings'  = (New-ScheduledTaskSettingsSet -Hidden);
            'Trigger'   = (New-ScheduledTaskTrigger -AtLogOn);
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) New-ScheduledTask: $($newScheduledTask | Out-String)"

        $registerScheduledTask = @{
            'TaskName'    = $scheduledTaskName;
            'InputObject' = (New-ScheduledTask @newScheduledTask);
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Register-ScheduledTask: $($registerScheduledTask | Out-String)"
        Register-ScheduledTask @registerScheduledTask | Out-String | Write-Verbose

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Start-ScheduledTask: ${scheduledTaskName}"
        Start-ScheduledTask -TaskName $scheduledTaskName | Out-String | Write-Verbose


        for ($i = 100; $i -le 10000; $i + 100) {
            $scheduledTaskInfo = Get-ScheduledTaskInfo -TaskName $scheduledTaskName
            Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Waiting for ScheduledTask to Run; Last Task Result: [$($scheduledTaskInfo.LastRunTime)] $($scheduledTaskInfo.LastTaskResult)"
            if ($scheduledTaskInfo.LastTaskResult -eq 267011) {
                Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) $($scheduledTaskInfo.LastTaskResult): ScheduledTask *likely* hasn't run yet."
            } elseif ($scheduledTaskInfo.LastTaskResult -eq 267009) {
                Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) $($scheduledTaskInfo.LastTaskResult): ScheduledTask *likely* is running."
                if (-not $Wait.IsPresent) {
                    break
                }
            }

            if ($scheduledTaskInfo.LastTaskResult -eq 0) {
                break
            } else {
                Start-Sleep -Milliseconds $i
            }
        }

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Unregister ScheduledTask: ${scheduledTaskName}"
        Unregister-ScheduledTask -TaskName $scheduledTaskName -Confirm:$false -Verbose

        if (-not (Get-ScheduledTask -TaskName $scheduledTaskName -ErrorAction SilentlyContinue)) {
            $schtasks = (Get-Command 'SCHTASKS' -ErrorAction SilentlyContinue).Path
            if ($schtasks) { # Seems AppVeyor doesn't have SCHTASKS avail.
                & $schtasks /Delete /TN $scheduledTaskName /F
            }
        }

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Delete VBS: ${vbscriptFile}"
        Remove-Item $vbscriptFile -Force -Verbose
    } #/function private:Invoke-AsUser

    [IO.FileInfo] $jsonFilePath = "$($LicenseManager.DirectoryPath)\${ProcessName}.json"
    Write-Verbose "[Deny-LMEntry] JSON File: ${jsonFilePath}"

    $ProcessConcurrentMax = $LicenseManager.Processes.$ProcessName
    Write-Verbose "[Deny-LMEntry] Process Concurrent Max: ${ProcessConcurrentMax}"

    $process = Get-Process -Id $ProcessId -IncludeUserName
    Write-Verbose "[Deny-LMEntry] Process: $($process | Out-String)"

    [IO.FileInfo] $processPath = $process.Path
    $productName = if ($processPath.VersionInfo.FileDescription) { $processPath.VersionInfo.FileDescription } elseif ($processPath.VersionInfo.ProductName) { $processPath.VersionInfo.ProductName } else { $ProcessName.BaseName }

    $blockedAppMessage = @'
A valid license could not be obtained by the network license manager.

The application you are trying to access ({1}) has exceeded its maximum concurency of {2}. Please try again later. If you feel like this message is an error, please contact your system administrator or IT department.

Error [{3},{4},{5},{6}]
{0}
'@

    $blockedAppVBS = @'
Dim wshShell: Set wshShell = WScript.CreateObject("WScript.Shell")
WshShell.Popup "{0}", {1}, "{2}", {3}
'@ -f @(
        $($blockedAppMessage.Replace([System.Environment]::NewLine, '"& vbCrLf &"').Replace("`n", '"& vbCrLf &"').Replace('vbCrLf &""& vbCrLf', 'vbCrLf & vbCrLf') -f @(
            (Get-Date -Format 'O')
            $productName
            $ProcessConcurrentMax
            $process.UserName
            (hostname)
            $ProcessId
            $ProcessName
        )),
        0,
        "License Manager: ${productName}",
        16
    )
    Write-Verbose "[Deny-LMEntry] Blocked App VBS:`n$($blockedAppVBS | Out-String)"

    Write-Verbose "[Deny-LMEntry] Notifying User ..."
    Invoke-AsUser -User $ProcessUserName -Command $blockedAppVBS -IsVBScript

    Write-Verbose "[Deny-LMEntry] Stopping Process: ${ProcessId} ${process} $($process.Username)"
    Stop-Process -Id $ProcessId -Force


    if (-not (Get-Command 'Write-LMEntryDenial' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Write-LMEntryDenial.ps1"
    }

    Write-Verbose "[Deny-LMEntry] Logging Denial..."
    Write-LMEntryDenial -LicenseManager $LicenseManager -ProcessName $ProcessName -ProcessId $ProcessId -ProcessUserName $ProcessUserName
}
