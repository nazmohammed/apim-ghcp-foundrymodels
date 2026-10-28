using 'main.bicep'

param apimName = 'apim-ghcp-byom-<unique>'
param publisherEmail = 'you@contoso.com'
param publisherName = 'Contoso'

param ptuAccountName = '<foundry-account-with-ptu>'
// param paygAccountName = '<foundry-account-payg>'   // enables PTU -> PAYG spillover (step 4+)

param policyStep = 4
param tokensPerMinute = 200000
// param allowedModels = [ 'gpt-5.5', 'gpt-5.6-sol' ]   // required for step 5+
