@{
    ProcessIdFinalAdd            = @(7)
    ProcessIdFinalRemove         = @(7)
    TimeStampWillNotUpdateRemove = $true
    StartingJson                 = @'
{
    "UserName":  "Test\\Pester",
    "ProcessId":  [
                      7
                  ],
    "ComputerName":  "",
    "TimeStamp":  "Thursday, June 22, 2017 5:43:33 PM"
}
'@
    NewProcessAllowed            = $true
}