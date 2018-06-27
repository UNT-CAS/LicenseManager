@{
    ProcessIdFinalAdd    = @(7, 77)
    ProcessIdFinalRemove = @()
    StartingJson         = @'
{
    "UserName":  "Test\\Pester",
    "ProcessId":  [
                      77
                  ],
    "ComputerName":  "",
    "TimeStamp":  "Thursday, June 22, 2017 5:43:33 PM"
}
'@
    NewProcessAllowed    = $true
}