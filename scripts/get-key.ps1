param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $ApimName,
    [string] $SubscriptionName = 'vscode-dev'
)

$sub = az account show --query id -o tsv
$url = "https://management.azure.com/subscriptions/$sub/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/subscriptions/$SubscriptionName/listSecrets?api-version=2024-05-01"
az rest --method post --url $url --query primaryKey -o tsv
