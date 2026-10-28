param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [string] $Location = 'swedencentral',
    [string] $ParameterFile = "$PSScriptRoot\..\infra\main.bicepparam",
    [ValidateRange(1, 6)] [int] $PolicyStep
)

$ErrorActionPreference = 'Stop'
az group create --name $ResourceGroup --location $Location | Out-Null

$extra = @()
if ($PSBoundParameters.ContainsKey('PolicyStep')) { $extra += @('--parameters', "policyStep=$PolicyStep") }

az deployment group create `
    --resource-group $ResourceGroup `
    --parameters $ParameterFile @extra `
    --query properties.outputs
