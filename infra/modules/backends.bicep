param apimName string

@description('PTU endpoint base, e.g. https://<account>.openai.azure.com/openai')
param ptuEndpoint string

@description('Optional pay-as-you-go endpoint used for spillover. Leave empty to disable.')
param paygEndpoint string = ''

var hasPayg = !empty(paygEndpoint)
var ptuName = 'foundry-ptu'
var paygName = 'foundry-payg'
var poolName = 'foundry-pool'

// Trip on throttling / transient errors so the pool moves traffic to the next priority.
var circuitBreaker = {
  rules: [
    {
      name: 'throttle-breaker'
      failureCondition: {
        count: 1
        interval: 'PT10S'
        statusCodeRanges: [
          { min: 429, max: 429 }
          { min: 500, max: 503 }
        ]
      }
      tripDuration: 'PT10S'
      acceptRetryAfter: true
    }
  ]
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource ptu 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: ptuName
  properties: {
    description: 'Foundry PTU deployment'
    type: 'Single'
    protocol: 'http'
    url: ptuEndpoint
    circuitBreaker: circuitBreaker
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource payg 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if (hasPayg) {
  parent: apim
  name: paygName
  properties: {
    description: 'Foundry pay-as-you-go deployment (spillover)'
    type: 'Single'
    protocol: 'http'
    url: paygEndpoint
    circuitBreaker: circuitBreaker
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource pool 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if (hasPayg) {
  parent: apim
  name: poolName
  dependsOn: [
    ptu
    payg
  ]
  properties: {
    description: 'PTU first (priority 1), PAYG spillover (priority 2)'
    type: 'Pool'
    pool: {
      services: [
        {
          id: resourceId('Microsoft.ApiManagement/service/backends', apimName, ptuName)
          priority: 1
          weight: 1
        }
        {
          id: resourceId('Microsoft.ApiManagement/service/backends', apimName, paygName)
          priority: 2
          weight: 1
        }
      ]
    }
  }
}

output ptuBackendName string = ptu.name
output poolBackendName string = hasPayg ? poolName : ''
