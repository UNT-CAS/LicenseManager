[![Build status](//ci.appveyor.com/api/projects/status/t3kx0sy41ouw7cry?svg=true)](https://ci.appveyor.com/project/VertigoRay/licensemanager)
[![downloads](//img.shields.io/powershellgallery/dt/licensemanager.svg?label=downloads)](https://www.powershellgallery.com/packages/licensemanager)
[![codecov](//codecov.io/gh/UNT-CAS/LicenseManager/branch/master/graph/badge.svg)](https://codecov.io/gh/UNT-CAS/LicenseManager)

Manage concurrent usage of software that doesn't use a smarter license server, such as Flex LM.

# Description

We have several pieces of software that don't use a license server.
Because of this, we own *n* number of stand-alone licenses.
When applicable, we can install this on as many computers as we want, such as in a VDI farm, and make it availble as long as we can control concurrency.
This is an attempt to control concurrency in these situations.

I prefer to run this as a scheduled task that triggers at reboot and re-runs every 15 minutes or so; ensure:

- If it's already running, another one doesn't startup.
- It's never forced to die after a timeout.

This ensure that the process is always running. If it dies for some reason, we'll get it running again within 15 minutes

# Quick Setup

1. Set the `$env:LicenseManager` Environment Variable; see [the section below](#envlicensemanager).
1. Install `LicenseManager`: `Install-Module LicenseManager`.
1. Import `LicenseManager`: `Import-Module LicenseManager`.
1. Start `LicenseManager`: `Invoke-LicenseManager`.

## `$env:LicenseManager`

Using a `[hashtable]`, make two keys:

- `[string] DirectoryPath`: See [DirectoryPath parameter](#directorypath).
- `[hashtable] Processes`: See [Processes parameter](#directorypath).
  - Each `Name` is the process name with extension.
  - Each  `Value` is an `[int]` of the number of concurrent processes allowed to run.

When that's done, convert it to a compressed JSON and set it as the `$env:LicenseManager` environment variable.
I suggest setting it via the same GPO that you use to run this at startup.
Here's a quick example:

```powershell
$LicenseManager = @{
    DirectoryPath = '\\license\LicenseManager'
    Processes     = @{
        'notepad.exe'    = 5
        'Calculator.exe' = 10
    }
}
$env:LicenseManager = $LicenseManager | ConvertTo-Json -Compress
```

# Parameters

There's really only one JSON string parameter: `LicenseManager`.
You can see it in the `Watch-LMEvent.ps1` script.
This is the *main* script.
The Parameter should look like this

```json
{
    "DirectoryPath":  "\\\\license\\LicenseManager",
    "Processes":  {
                    "notepad.exe":  5,
                    "Calculator.exe":  10
                }
}
```

## DirectoryPath

- Type: `[string]`

This should likely be a UNC path.
If you're running as `NT AUTHORITY\System`, be sure to grant *domain computers* read/write access to the the UNC path.

## Processes

- Type: `[hashtable]`
  - Each `Name` is the process name with extension.
  - Each  `Value` is an `[int]` of the number of concurrent processes allowed to run.
