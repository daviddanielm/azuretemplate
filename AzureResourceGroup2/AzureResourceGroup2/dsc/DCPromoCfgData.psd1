# Configuration Data script for Domain Controller
@{             
    AllNodes = @(             
        @{             
            Nodename = "localhost"             
            Role = "Domain Controller"             
            #DomainName = "dscdomain.ro"             
            RetryCount = 50              
            RetryIntervalSec = 25            
            PsDscAllowPlainTextPassword = $true            
        }    
    )             
}  