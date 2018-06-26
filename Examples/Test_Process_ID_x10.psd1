@{
    ProcessIdFinal    = @(11, 22, 33, 44, 55, 66, 77, 88, 99, 1010, 7)
    StartingJson      = @'
{
    "UserName":  "Test\\Pester",
    "ProcessId":  [
                      11, 22, 33, 44, 55, 66, 77, 88, 99, 1010
                  ],
    "ComputerName":  "",
    "TimeStamp":  "Thursday, June 22, 2017 5:43:33 PM"
}
'@
    NewProcessAllowed = $true
}