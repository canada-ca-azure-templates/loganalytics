Param(
    [Parameter(Mandatory = $True)][string]$templateLibraryName = "name of template",
    [Parameter(Mandatory = $True)][string]$templateLibraryVersion = "version of template",
    [string]$templateName = "azuredeploy.json",
    [string]$containerName = "library-dev",
    [string]$prodContainerName = "library",
    [string]$storageRG = "PwS2-Infra-Storage-RG",
    [string]$storageAccountName = "azpwsdeploytpnjitlh3orvq",
    [string]$Location = "canadacentral"
)

function Output-DeploymentName {
    param( [string]$Name)

    $pattern = '[^a-zA-Z0-9-]'

    # Remove illegal characters from deployment name
    $Name = $Name -replace $pattern, ''

    # Truncate deplayment name to 64 characters
    $Name.subString(0, [System.Math]::Min(64, $Name.Length))
}
$devBaseTemplateUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/arm"
$prodBaseTemplateUrl = "https://$storageAccountName.blob.core.windows.net/$prodContainerName/arm"

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Cleanup old jobs
Get-Job | Remove-Job

Set-AzureRmCurrentStorageAccount -ResourceGroupName $storageRG -Name $storageAccountName
    
#Create the SaS token for the dev contrainer
$devToken = New-AzureStorageContainerSASToken -Name $containerName -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0)
$prodToken = New-AzureStorageContainerSASToken -Name $prodContainerName -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0)


# Start the deployment
Write-Host "Starting deployment...";

# Building dependencies needed for the server validation
New-AzureRmDeployment -Location $Location -Name "dependancy-$templateLibraryName-Build-resourcegroups" -TemplateUri ("$prodBaseTemplateUrl/resourcegroups/20190207.2/$templateName" + $prodToken) -TemplateParameterFile (Resolve-Path "$PSScriptRoot\dependancy-resourcegroups-canadacentral.parameters.json") -containerSasToken $prodToken -Verbose
Get-Job | Wait-Job
Get-Job | Receive-Job

if (Get-Job -State Failed) {
    Write-Host "One of the jobs was not successfully created... exiting..."
    exit
}

# Cleanup old jobs before running new deployments
Get-Job | Remove-Job

# Validating server template
#Write-Host New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-keyvaults-1-RG -Name "validate-$templateLibraryName-Build-$templateLibraryName" -TemplateUri "$devBaseTemplateUrl/keyvaults/$templateLibraryVersion/$templateName" -TemplateParameterFile (Resolve-Path "$PSScriptRoot\validate-keyvaults.parameters.json") -_debugLevel "requestContent,responseContent" -Verbose
New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-keyvaults-1-RG -Name "validate-$templateLibraryName-Build-$templateLibraryName" -TemplateUri "$devBaseTemplateUrl/keyvaults/$templateLibraryVersion/$templateName" -TemplateParameterFile (Resolve-Path "$PSScriptRoot\validate-keyvaults.parameters.json") -_debugLevel "requestContent,responseContent" -Verbose

# Cleanup validation resource content
Write-Host "Cleanup validation resource content...";
New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-keyvaults-1-RG -Mode Complete -TemplateFile (Resolve-Path "$PSScriptRoot\cleanup.json") -Force -Verbose