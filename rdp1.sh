# Self-elevate the script if required
"`Self Elevating...`n"
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

"`nChecking/mitigating Powershell Execution Policy...`n"
if($(Get-ExecutionPolicy) -ne 'RemoteSigned')
{
`set-executionpolicy remotesigned
}

"`nInitiating settings and dependencies pre-check/installation`n"
"`nChecking/mitigating Remote Desktop...`n"
#Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1


"`nChecking/mitigating Azure Powershell module...`n"
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
   Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
   'Az modules installed at the same time is not supported.')
} else {
     Install-Module -Name Az -AllowClobber -Scope CurrentUser
}

"`nGetting Azure Credentials and authenticating...`n"

Connect-AzAccount

"`nChecking Azure VM status...`n"

#$status =  Get-AzVM `
#   -ResourceGroupName "<RESOURCEGROUPNAMEHERE>" `
#   -Name "<VMNAMEHERE>" -Status

#Write-Output $status.Statuses.DisplayStatus

#if($($status.Statuses.DisplayStatus) -ne "VM deallocated")
#{
#    pause("Please try again later")
#    exit
#}

"`nStarting Azure VM <RESOURCEGROUPNAMEHERE> <VMNAMEHERE>...`n"

Start-AzVM `
   -ResourceGroupName "<RESOURCEGROUPNAMEHERE>" `
   -Name "<VMNAMEHERE>"

"`nGetting public IP of <VMNAMEHERE>...`n"


$ip = Get-AzPublicIpAddress `
   -ResourceGroupName "<RESOURCEGROUPNAMEHERE>"  | Select IpAddress

"`nStarting remote desktop session...`n"

mstsc /v:$($ip.{IpAddress})

Start-Sleep -s 60

$rdpsession = Get-Process mstsc -ErrorAction SilentlyContinue

Write-Output $rdpsession

"`nYour session is up and now being tracked. Listening for remote desktop closure...`n"

$hasd = "false"

for(;;)
{
   $rdpsession = Get-Process mstsc -ErrorAction SilentlyContinue
    if (!$rdpsession) {
        "`nRemote desktop session ended.`n"

        Stop-AzVM `
           -ResourceGroupName "<RESOURCEGROUPNAMEHERE>" `
           -Name "<VMNAMEHERE>"

         $hasd = "true"

        "`nStopping <VMNAMEHERE>...`n"

        break
    }
}

Register-EngineEvent PowerShell.Exiting –Action { if($hasd -eq "false")
{
    Stop-AzVM `
           -ResourceGroupName "<RESOURCEGROUPNAMEHERE>" `
           -Name "<VMNAMEHERE>"

        "`nStopping <VMNAMEHERE>...`n"
}}


Function pause ($message)
{
    # Check if running Powershell ISE
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else
    {
        Write-Host "$message" -ForegroundColor Yellow
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}