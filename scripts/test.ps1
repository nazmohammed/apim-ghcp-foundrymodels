param(
    [Parameter(Mandatory)] [string] $ApimName,
    [Parameter(Mandatory)] [string] $SubscriptionKey,
    [Parameter(Mandatory)] [string] $Model,
    [string] $Prompt = 'Reply with the single word: pong',
    [switch] $SendMaxTokens
)

$body = @{ model = $Model; messages = @(@{ role = 'user'; content = $Prompt }) }
# Simulates the VS Code / GitHub proxy payload that triggers the max_tokens error without policy step 6.
if ($SendMaxTokens) { $body.max_tokens = 256; $body.temperature = 0.1 }

Invoke-RestMethod -Method Post `
    -Uri "https://$ApimName.azure-api.net/openai/v1/chat/completions" `
    -Headers @{ 'api-key' = $SubscriptionKey } `
    -ContentType 'application/json' `
    -Body ($body | ConvertTo-Json -Depth 5) |
    ConvertTo-Json -Depth 6
