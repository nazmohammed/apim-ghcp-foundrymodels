targetScope = 'resourceGroup'

@description('API Management instance name (globally unique).')
param apimName string
param location string = resourceGroup().location
param publisherEmail string
param publisherName string

@description('Foundry / Azure OpenAI account hosting the PTU deployments (same subscription).')
param ptuAccountName string
param ptuAccountResourceGroup string = resourceGroup().name

@description('Optional pay-as-you-go Foundry account used for PTU spillover (policy step 4+).')
param paygAccountName string = ''
param paygAccountResourceGroup string = resourceGroup().name

@description('How many policy steps to apply (1-6). Each step includes the previous ones. See README.')
@minValue(1)
@maxValue(6)
param policyStep int = 4

@description('Per-subscription token budget per minute (step 2+).')
param tokensPerMinute int = 200000

@description('Allowed model/deployment names (step 5+). An empty list blocks every request.')
param allowedModels array = []

var hasPayg = !empty(paygAccountName)

module apim 'modules/apim.bicep' = {
  name: 'apim'
  params: {
    apimName: apimName
    location: location
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

module ptuAccess 'modules/foundry-access.bicep' = {
  name: 'ptu-access'
  scope: resourceGroup(ptuAccountResourceGroup)
  params: {
    accountName: ptuAccountName
    principalId: apim.outputs.principalId
  }
}

module paygAccess 'modules/foundry-access.bicep' = if (hasPayg) {
  name: 'payg-access'
  scope: resourceGroup(paygAccountResourceGroup)
  params: {
    accountName: paygAccountName
    principalId: apim.outputs.principalId
  }
}

module backends 'modules/backends.bicep' = {
  name: 'backends'
  params: {
    apimName: apim.outputs.name
    ptuEndpoint: 'https://${ptuAccountName}.openai.azure.com/openai'
    paygEndpoint: hasPayg ? 'https://${paygAccountName}.openai.azure.com/openai' : ''
  }
}

// Pool routing only makes sense from step 4 and only when a PAYG account exists.
var backendId = (policyStep >= 4 && hasPayg) ? backends.outputs.poolBackendName : backends.outputs.ptuBackendName

module api 'modules/api.bicep' = {
  name: 'api'
  params: {
    apimName: apim.outputs.name
    loggerName: apim.outputs.loggerName
    backendId: backendId
    policyStep: policyStep
    tokensPerMinute: tokensPerMinute
    allowedModels: allowedModels
  }
}

output gatewayUrl string = apim.outputs.gatewayUrl
output chatCompletionsUrl string = '${apim.outputs.gatewayUrl}/openai/v1/chat/completions'
output subscriptionName string = api.outputs.subscriptionName
