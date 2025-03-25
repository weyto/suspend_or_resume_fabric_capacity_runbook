Param(
    [string]$ResourceID, # e.g. "/subscriptions/12345678-1234-1234-1234-123a12b12d1c/resourceGroups/fabric-rg/providers/Microsoft.Fabric/capacities/myf2capacity"
    [ValidateSet("suspend", "resume")]
    [string]$operation # "suspend" or "resume"
)

#$ResourceID = "/subscriptions/12345678-1234-1234-1234-123a12b12d1c/resourceGroups/fabric-rg/providers/Microsoft.Fabric/capacities/myf2capacity"
#$operation = "suspend" 
#$operation = "resume"

$ErrorActionPreference = "Stop"

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$tokenObject = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$token = $tokenObject.AccessToken
$headers = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer $token"
}

$capacityUrl = "https://management.azure.com$ResourceID" + "?api-version=2023-11-01"
$capacityResourceResponse = Invoke-RestMethod -Uri $capacityUrl -Method Get -Headers $headers

if ($operation -eq "suspend" -and $capacityResourceResponse.properties.state -ne "Active") {
    Write-Warning "Cannot suspend. Current state: $($capacityResourceResponse.properties.state)"
    return
}
if ($operation -eq "resume" -and $capacityResourceResponse.properties.state -ne "Suspended") {
    Write-Warning "Cannot resume. Current state: $($capacityResourceResponse.properties.state)"
    return
}

$capacityOperationActionUrl = "https://management.azure.com$ResourceID/$operation" + "?api-version=2023-11-01"
Write-Output $capacityOperationActionUrl

$response = Invoke-RestMethod -Uri $capacityOperationActionUrl -Method Post -Headers $headers
$response
if ($response.status -ne "Succeeded") {    
    throw "Capacity operation did not succeed."
}
