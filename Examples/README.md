Each of these examples is a hashtable of data.
These are used for testing by the Pester Tests.
Hopefully, this document will make it a little easier to understand what's in the files.

# Description

## Test Entry

```powershell
@{
    LicenseManager  = @{
        DirectoryPath = "%ProjectRoot%\dev"
        Processes = @{
            'notepad.exe' = 5
            'Calculator.exe' = 10
            '10d5c669-9386-4c97-9626-2a21a29c5ec3' = 2
        }
    }
    ProcessName     = '10d5c669-9386-4c97-9626-2a21a29c5ec3'
    ProcessId       = 7
    ProcessUserName = 'Test\Pester'
}
```

*Note: see the main README to know what `%ProjectRoot%` is.*
*The `dev` folder is in `.gitignore`.*

*Note: the GUID (`10d5c669-9386-4c97-9626-2a21a29c5ec3`) is a random and unique per test iteration.*

# Parameters

For lack of a better term, I'm going to call each item in the hashtable a *parameter*.

## Name

- Type: `[string]`
- Default: `$null`

This parameter is taken from the file name.
Underscores (`_`) are replaced with spaces (` `).

*Note: adding it to the file as well would cause and error that I could easily fix, but I don't care to.*

## JsonInitiallyDoesNotExist

- Type: `[bool]`
- Default: `$false`

This is for testing what happens if the JSON file doesn't exist.
Set to true if you don't want a JSON file.
Otherwise, an empty JSON file will be generated.

## ProcessIdFinalAdd

- Type: `[int[]]`
- Default: `@()`

This is what the final ProcessID, in the JSON file, should be after adding the test process.

## ProcessIdFinalRemove

- Type: `[int[]]`
- Default: `@()`

This is what the final ProcessID, in the JSON file, should be after removing the test process.

## StartingJson

- Type: `[string]`
- Default: `$null`

Use this parameter if you'd like to specify the starting JSON file.

- **ComputerName**: If you leave this an an *empty string*, it will be filled in with `$env:ComputerName`.

## NewProcessAllowed

- Type: `[bool]`
- Default: `$false`

This is for determining what the answer to `Assert-LMEntry` should be.