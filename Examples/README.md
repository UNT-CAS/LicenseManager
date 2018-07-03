Each of these examples is a hashtable of data.
These are used for testing by the Pester Tests.
Hopefully, this document will make it a little easier to understand what's in the files.

# Description

Each Function has it's own set of examples.
It should be obvious, but the function's example's file name starts with the function's name; followed by a description of the test.

## Test Entry

```powershell
@{
    Parameters = @{
        LicenseManager = @{
            DirectoryPath = '%ProjectRoot%\dev\LicenseManager'
            Processes     = @{
                '19f3c7a5-8e6a-4379-ab73-b65c2f0a0ea7' = 2
                'notepad.exe'                          = 5
                'Calculator.exe'                       = 10
            }
        }
        ProcessName = '19f3c7a5-8e6a-4379-ab73-b65c2f0a0ea7'
        ProcessId = 19
        ProcessUserName = 'Test\Pester'
    }
    ...
}
```

*Note: see the main README to know what `%ProjectRoot%` is.*
*The `dev` folder is in `.gitignore`.*

*Note: the GUID (`19f3c7a5-8e6a-4379-ab73-b65c2f0a0ea7`) is a random guid for testing purposes.*
*A real Process Name would be something like: `notepad.exe`, `Calculator.exe`, etc..*

*Note: the `...` basically tells you that there are likely more main keys, but they are specific to each function we're testing.*

# Example File Name

The example file name follows a pattern: `%FunctionName%.%TestDescription%.psd1`.

- `%FunctionName%`: The function name that we're testing. The Pester test will filter to examples beginning with the function name that it was written for. So, this can't have typos or it won't be included in the test.
- `%TestDescription%`: The description of the test. This is used to define the Pester *Context* that we're in. Underscores (`_`) are replaced with spaces.
- `psd1`: a PowerShell Data file; see [Import-PowerShellDataFile](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-powershelldatafile) for more information.

# Main Keys

For lack of a better term, I'm going to call each item in the hashtable a *main key*.

## Parameters

- Type: `[hashtable]`
- Default: `$null`

This is used for splatting into the function that we're testing.
See the fu

*Note: adding it to the file as well would cause and error that I could easily fix, but I don't care to.*

## ExistingCsv

- Type: `[bool]` or `[string]`
- Default: `$false`
- Function Tests: `Write-LMEntryDenial`

If `[bool]` then we will ensure the test starts with an empty CSV (`$true`) or without a CSV at all (`$false`).

If `[string]` then we will ensure the test starts with a CSV with the contents set to value of this variable.

## ExistingJson

- Type: `[bool]` or `[string]`
- Default: `$false`
- String Replacement:
    - `{0}`: The name of the current computer.
- Function Tests: `Add-LMEntry`

If `[bool]` then we will ensure the test starts with an empty JSON (`$true`) or without a JSON at all (`$false`).

If `[string]` then we will ensure the test starts with a JSON with the contents set to value of this variable.

## ExpectedCsv

- Type: `[string]`
- Default: `$false`
- String Replacement:
    - `{0}`: The name of the current computer.
    - `{1}`: Timestamp from one minute ago.
- Function Tests: `Write-LMEntryDenial`

We will test the resultant CSV (the CSV created from calling the function) with the value of this variable to ensure they are the same.

## ExpectedJson

- Type: `[bool]` or `[string]`
- Default: `$false`
- String Replacement:
    - `{0}`: The name of the current computer.
    - `{1}`: Timestamp from one minute ago.
- Function Tests: `Add-LMEntry`

If `[bool]` and `$false` then we will ensure there is no change to the JSON at all.
There's no support for `[bool]` and `$true`.

If `[string]` then we will test the resultant JSON (the JSON created from calling the function) with the value of this variable to ensure they are the same.







:bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: 
**WORK IN PROGRESS; BELOW THIS LINE!!**
:bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: :bangbang: 

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

## TimeStampWillNotUpdateRemove

- Type: `[bool]`
- Default: `$false`

When removing an entry, the entry might not exist.
So we set this to skip that test.