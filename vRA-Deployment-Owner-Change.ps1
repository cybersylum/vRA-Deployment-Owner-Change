<#
vRA-Deployment-Owner-Change.ps1

This script will update the owner of all deployments in a vRA instance, changing them all to a common user/group.  It is intended to be run once as a clean-up or bulk change task.

It may be useful to perform this task during blueprint or onboarding deployments.  An example of this (using ABX Action) is https://vmwarecode.com/2021/11/24/vra-cloud-add-the-users-in-projects-and-change-the-owner-of-deployment-dynamically-using-python-abx-action/

Disclaimer:  This script was obtained from https://github.com/cybersylum
  * You are free to use or modify this code for your own purposes.
  * No warranty or support for this code is provided or implied.  
  * Use this at your own risk.  
  * Testing is highly recommended.
#>

##
## Define Environment Variables
##
$vRAServer = "vra.company.com"
$vRAUser = "user@company.com"
$DateStamp=Get-Date -format "yyyyMMdd"
$TimeStamp=Get-Date -format "hhmmss"
$RunLog = "vRA-Deployment-Owner-Change-$DateStamp-$TimeStamp.log"

<#
User/Group to set as owner of deployments

The user or group used must be added to the Aria Automation Project as a member or owner before running this script.

To set user as owner
    NewOwner = "username" - ie: joetest
    NewOwnerType = "USER"

to set Group as owner
    NewOwner = "group@domain.com" - ie: vRA-Deployments@mycompany.com
    NewOwnerType = "AD_GROUP"
#>
$NewOwner = "vRA-Deployments@company.com"
$NewOwnerType = "AD_GROUP"

# Rate Limiting controls to avoid overloading the Automation server.  This operation will update all resources included in a deployment and can be taxing
# $RateLimit is # of write transactions to perform before pausing for $RatePause seconds
$RateLimit=10  
$RatePause=30 #in seconds

# QueryLimit is used to control the max rows returned by invoke-restmethod (which has a default of 100)
$QueryLimit=9999

##
## Function declarations
##
function Write-Log  {

    param (
        $LogFile,
        $LogMessage    
    )

    # complex strings may require () around message paramter 
    # Write-Log $RunLog ("Read " + $NetworkData.count + " records from $ImportFile. 1st Row is expected to be Column Names as defined in script.")

    $LogMessage | out-file -FilePath $LogFile -Append
}

function Get-Deployments {

$Body = @{
    '$top' = $QueryLimit
}
$APIparams = @{
    Method = "GET"
    Uri = "https://$vRAServer/deployment/api/deployments"
    Authentication = "Bearer"
    Token = $APItoken
    Body = $Body
}
try{
    $vRADeployments = (Invoke-RestMethod @APIparams -SkipCertificateCheck).content
} catch {
    Write-Log $RunLog $("    Unable to get Deployments from vRA")
    Write-Log $RunLog $Error
    Write-Log $RunLog $Error[0].Exception.GetType().FullName
}

    $results = @()
    foreach ($vRADeployment in $vRADeployments) {
        $results += @{
            ID = $vRADeployment.id
            Name = $vRADeployment.name
            Owner = $vRADeployment.ownedBy    
        }
    }

    return $results
    }



function Update-DeploymentOwner { 
    param (
        $ID,
        $ChangeOwner,
        $ChangeOwnerType
    )   

    $Body = @{
        "actionId" = "Deployment.ChangeOwner"
        "inputs" = @{
            "newOwner" = "$ChangeOwner"
            "ownerType" = "$ChangeOwnerType"
        }
    }

    $APIparams = @{
        Method = "POST"
        Uri = "https://$vRAServer/deployment/api/deployments/$ID/requests"
        Authentication = "Bearer"  
        Token = $APItoken
        Body = ($Body | ConvertTo-Json)
        ContentType = "application/json"
    }

    Try {
        $Results=Invoke-RestMethod @APIparams -SkipCertificateCheck
        Write-Log $RunLog $("   Updated $ID")
    } catch {
        Write-Log $RunLog "    Unable to Update Owner - " + $ID
        Write-Log $RunLog $Error
        Write-Log $RunLog $Error[0].Exception.GetType().FullName
    }

}

##
## Main Script
##

#Connect to vRA
write-host "Connecting to Aria Automation - $vRAServer as $vRAUser"
$vRA=connect-vraserver -server $vRAServer -Username "$vRAUser" -IgnoreCertRequirements
if ($vRA -eq $null) {
    write-host "Unable to connect to vRA Server '$vRAServer'..."
    Write-Log $RunLog ("Unable to connect to vRA Server '$vRAServer'...")
    exit
}

#Grab the bearer token for use with invoke-restmethod
$APItoken= $vRA.token | ConvertTo-SecureString -AsPlainText -Force

write-host "Getting deployments from from $vRAServer"
Write-Log $RunLog $("Getting deployments from from $vRAServer")

$RateCounter = 0

$deployments = Get-Deployments
$deploymentcount = $deployments.count
Write-Log $RunLog $("Found $deploymentcount deployments")
Write-Log $RunLog $("All deployments will be updated and owned by $NewOwner")

write-host "Verifying Deployment Ownership.  New Owner will be - $NewOwner"
foreach ($deployment in $deployments) {
    $id = $deployment.id
    $name = $deployment.Name
    $owner = $deployment.Owner

    write-host $name

    if ($deployment.Owner -eq $NewOwner) {
        Write-Log $RunLog $("$name already owned by $NewOwner")
    } else {
        Write-Log $RunLog $("Updating owner for $name")
        Update-DeploymentOwner $id $NewOwner $NewOwnerType
        #Increment Rate Counter to avoid overload on updates
        $RateCounter++
    }

    #Rate Limit to avoid overload
    if ($RateCounter -gt $RateLimit) {
        write-host "Sleeping for $RatePause seconds to avoid overload"
        start-sleep -seconds $RatePause
        $RateCounter = 0
    }
}
 
# Clean up
write-host
Write-Host "More details available in the log - $RunLog"
Disconnect-vRAServer -Confirm:$false
