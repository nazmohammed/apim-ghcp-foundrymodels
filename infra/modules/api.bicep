param apimName string
param loggerName string

@description('Backend (single or pool) the policy routes to.')
param backendId string

@minValue(1)
@maxValue(6)
param policyStep int
param tokensPerMinute int
param allowedModels array

var policies = [
  loadTextContent('../../policies/01-managed-identity.xml')
  loadTextContent('../../policies/02-token-limit.xml')
  loadTextContent('../../policies/03-token-metrics.xml')
  loadTextContent('../../policies/04-ptu-spillover.xml')
  loadTextContent('../../policies/05-model-allowlist.xml')
  loadTextContent('../../policies/06-reasoning-model-compat.xml')
]

var allowedModelsLiteral = join(map(allowedModels, m => '"${m}"'), ', ')

var policyXml = replace(
  replace(
    replace(policies[policyStep - 1], '__BACKEND_ID__', backendId),
    '__TOKENS_PER_MINUTE__',
    string(tokensPerMinute)
  ),
  '__ALLOWED_MODELS__',
  allowedModelsLiteral
)

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'foundry-openai'
  properties: {
    displayName: 'Foundry OpenAI v1 (GHCP BYOM)'
    path: 'openai'
    protocols: [ 'https' ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
  }
}

resource chatCompletions 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'chat-completions'
  properties: {
    displayName: 'Chat Completions'
    method: 'POST'
    urlTemplate: '/v1/chat/completions'
  }
}

resource responses 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'responses'
  properties: {
    displayName: 'Responses'
    method: 'POST'
    urlTemplate: '/v1/responses'
  }
}

resource policy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

resource diagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01' = {
  parent: api
  name: 'applicationinsights'
  properties: {
    loggerId: resourceId('Microsoft.ApiManagement/service/loggers', apimName, loggerName)
    alwaysLog: 'allErrors'
    metrics: true
    verbosity: 'information'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

resource product 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  parent: apim
  name: 'ghcp-byom'
  properties: {
    displayName: 'GHCP BYOM'
    description: 'Foundry models for GitHub Copilot in VS Code'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = {
  parent: product
  name: api.name
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: 'vscode-dev'
  dependsOn: [ productApi ]
  properties: {
    displayName: 'vscode-dev'
    scope: product.id
    state: 'active'
  }
}

output subscriptionName string = subscription.name
