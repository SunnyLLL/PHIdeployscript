param(
    [Parameter()]
    [string]
    $authKey = "#########"
)
function Install-Gateway([string] $gwPath)
{
    # uninstall any existing gateway
    UnInstall-Gateway

    Write-Host "Start Microsoft Integration Runtime installation"
    
    $process = Start-Process "msiexec.exe" "/i $gwPath /quiet /passive" -Wait -PassThru
    if ($process.ExitCode -ne 0)
    {
        throw "Failed to install Microsoft Integration Runtime. msiexec exit code: $($process.ExitCode)"
    }
    Start-Sleep -Seconds 30

    Write-Host "Succeed to install Microsoft Integration Runtime"
}

function Register-Gateway([string] $key)
{
    Write-Debug " Start to register gateway with key: $key"
    $cmd = Get-CmdFilePath
    Start-Process $cmd "-k $key" -Wait
    Write-Debug " Succeed to register gateway"
}

function Check-WhetherGatewayInstalled([string]$name)
{
    $installedSoftwares = Get-ChildItem "hklm:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    foreach ($installedSoftware in $installedSoftwares)
    {
        $displayName = $installedSoftware.GetValue("DisplayName")
        if($DisplayName -eq "$name Preview" -or  $DisplayName -eq "$name")
        {
            return $true
        }
    }

    return $false
}


function UnInstall-Gateway()
{
    $installed = $false
    if (Check-WhetherGatewayInstalled("Microsoft Integration Runtime"))
    {
        [void](Get-WmiObject -Class Win32_Product -Filter "Name='Microsoft Integration Runtime Preview' or Name='Microsoft Integration Runtime'" -ComputerName $env:COMPUTERNAME).Uninstall()
        $installed = $true
    }

    if (Check-WhetherGatewayInstalled("Microsoft Integration Runtime"))
    {
        [void](Get-WmiObject -Class Win32_Product -Filter "Name='Microsoft Integration Runtime Preview' or Name='Microsoft Integration Runtime'" -ComputerName $env:COMPUTERNAME).Uninstall()
        $installed = $true
    }

    if ($installed -eq $false)
    {
        Write-Host "Microsoft Integration Runtime is not installed."
        return
    }

    Write-Host "Microsoft Integration Runtime has been uninstalled from this machine."
}

function Get-CmdFilePath()
{
    $filePath = Get-ItemPropertyValue "hklm:\Software\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager" "DiacmdPath"
    if ([string]::IsNullOrEmpty($filePath))
    {
        throw "Get-InstalledFilePath: Cannot find installed File Path"
    }

    return (Split-Path -Parent $filePath) + "\dmgcmd.exe"
}

function Validate-Input([string]$path, [string]$key)
{
    if ([string]::IsNullOrEmpty($path))
    {
        throw "Microsoft Integration Runtime path is not specified"
    }

    if (!(Test-Path -Path $path))
    {
        throw "Invalid Microsoft Integration Runtime path: $path"
    }

    if ([string]::IsNullOrEmpty($key))
    {
        throw "Microsoft Integration Runtime Auth key is empty"
    }
}

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

$ADFLocalDrive = "C:"                                                                                       #Drive where the below directory will be created.
$ADFLocalVMFolder = "ADFInstaller"                                                                          #Directory in which the .msi files will be downloaded.

$ADFIRDownloadURL = "https://download.microsoft.com/download/e/4/7/e4771905-1079-445b-8bf9-8a1a075d8a10/IntegrationRuntime_5.50.9181.2.msi"
$ADFIRLocalFileName = $ADFIRDownloadURL.Split("/")[$ADFIRDownloadURL.Split("/").Length-1]                   #Get the .msi filename.
$ADFIRInstallerLocalFileLocation = $ADFLocalDrive + '\' + $ADFLocalVMFolder + '\' + $ADFIRLocalFileName     #Local Path of downloaded installer.
Write-Debug " Creating directory to download the SHIR installable."
New-Item -Path "$ADFLocalDrive\$ADFLocalVMFolder) -ItemType Directory -Force                            #'-Force' Ok if directory already exists.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $ADFIRInstallerLocalFileLocation)) {
    Write-Debug "Downloading the SHIR installable at $ADFIRInstallerLocalFileLocation."
    Invoke-WebRequest -Uri $ADFIRDownloadURL -OutFile $ADFIRInstallerLocalFileLocation
} else {
    Write-Debug "SHIR installable already exists at $ADFIRInstallerLocalFileLocation. Skipping download."
}
Write-Host " $ADFIRInstallerLocalFileLocation"
Write-Host "Start to install integration runtime."
$MSIInstallArguments = @(
     "/i"
     "$ADFIRInstallerLocalFileLocation"
     "authKey='$authkey'"
     "/qb!"
     "/norestart"
 )
 #Write-Debug $MSIInstallArguments
UnInstall-Gateway
Start-Process "msiexec.exe" -ArgumentList $MSIInstallArguments  -Wait -NoNewWindow
Write-Host "installation integration runtime is finished."

#Validate-Input $path $authKey

#Install-Gateway $ADFIRInstallerLocalFileLocation
Register-Gateway $authKey
