configuration DCPromo
{             
   param             
    (   
        [Parameter(Mandatory)]
        [string]$DomainName,                    
        [Parameter(Mandatory)]            
        [pscredential]$DomainCreds    
    )             
            
    Import-DscResource -ModuleName xActiveDirectory, xDisk, xNetworking, cDisk, PSDesiredStateConfiguration, xComputerManagement
    [System.Management.Automation.PSCredential ]$Credentials = New-Object System.Management.Automation.PSCredential ("$DomainName\$($DomainCreds.UserName)", $DomainCreds.Password)

        $Interface=Get-NetAdapter | Where Name -Like "Ethernet*" | Select-Object -First 1
        $InterfaceAlias=$($Interface.Name)
             
    # Domain Controller         
    Node $AllNodes.Where{$_.Role -eq "Domain Controller"}.NodeName            
    {             
        # LCM Configuration   
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyAndMonitor'            
            RebootNodeIfNeeded = $true
			AllowModuleOverwrite = $true
			DebugMode='All'            
        }            
              
        # Install the data disk with no cache write option
        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }
        
        cDiskNoRestart DCDataDisk
        {
            DiskNumber = 2
            DriveLetter = "V"
        }            
        
        # Ensure that the AD Database Directory is created    
        File ADFiles            
        {            
            DestinationPath = 'V:\NTDS'            
            Type = 'Directory'            
            Ensure = 'Present'            
        }

        # AD services installation            
        WindowsFeature ADDSInstall             
        {             
            Ensure = "Present"             
            Name = "AD-Domain-Services"
            DependsOn="[cDiskNoRestart]DCDataDisk"             
        }            
            
        # Optional GUI tools and PS tools            
        WindowsFeature ADDS            
        {             
            Ensure = "Present"             
            Name = "RSAT-ADDS"             
        }            

        WindowsFeature ADDSTools {  
            Ensure = "Present"  
            Name  = "RSAT-ADDS-Tools"  
            DependsOn = "[WindowsFeature]ADDSInstall", "[WindowsFeature]ADDS"  
        }

        WindowsFeature ActiveDirectoryTools {  
            Ensure = 'Present'  
            Name = 'RSAT-AD-Tools'  
            DependsOn = "[WindowsFeature]ADDSInstall"  
        }  

        WindowsFeature ActiveDirectoryPowershell {  
            Ensure = "Present"  
            Name  = "RSAT-AD-PowerShell"  
            DependsOn = "[WindowsFeature]ADDSInstall"  
        }

        # Install DNS server 
        WindowsFeature DNSServerTools {  
            Ensure = 'Present'  
            Name = 'RSAT-DNS-Server'  
            DependsOn = "[WindowsFeature]ADDSInstall"  
        }  

        xDnsServerAddress DnsServerAddress { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
	        DependsOn = "[WindowsFeature]DNSServerTools"
        }

            
        # No slash at end of folder paths            
        xADDomain FirstDS             
        {             
            DomainName = $DomainName             
            DomainAdministratorCredential = $Credentials             
            SafemodeAdministratorPassword = $Credentials
            DatabasePath = 'V:\NTDS'            
            LogPath = 'V:\NTDS' 
            SysvolPath = "V:\SYSVOL"           
            DependsOn = "[WindowsFeature]ADDSInstall","[File]ADFiles"            
        }            
            
    } 
	            
}            
          

  
# Configuration Data for AD              
<#$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "localhost"             
            Role = "Domain Controller"             
            DomainName = "dscdomain.ro"             
            RetryCount = 20              
            RetryIntervalSec = 30            
            PsDscAllowPlainTextPassword = $true            
        }            
    )             
}             
            
DCPromo -ConfigurationData $ConfigData `
    -DomainName "dscdomain.ro" `
    #-safemodeAdministratorCred (Get-Credential -UserName '(Password Only)' `
        #-Message "New Domain Safe Mode Administrator Password") `
    -DomainCreds ($Credentials)            
            
# Make sure that LCM is set to continue configuration after reboot            
 #Set-DSCLocalConfigurationManager -Path .\NewDomain –Verbose            
            
# Build the domain            
 #Start-DscConfiguration -Wait -Force -Path .\NewDomain -Verbose            #>