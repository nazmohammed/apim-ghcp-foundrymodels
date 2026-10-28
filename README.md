# APIM Standard v2 → Foundry PTU models for GitHub Copilot BYOK (VS Code)

Azure API Management (Standard v2) as the gateway between VS Code / GitHub Copilot **bring-your-own-model** and Azure AI Foundry deployments (PTU first, optional pay-as-you-go spillover).

```
VS Code Copilot Chat ──(api-key = APIM subscription key)──▶ APIM Standard v2 ──(managed identity)──▶ Foundry PTU deployment
                                                              │  token limit · metrics · allow-list      └─(429/5xx spillover)▶ Foundry PAYG deployment
                                                              └─ body normalization (max_tokens → max_completion_tokens)
```

## Layout

| Path | Purpose |
|---|---|
| `infra/main.bicep` (+ `modules/`) | APIM StandardV2, App Insights, backends/pool, API, product, subscription, RBAC on Foundry |
| `policies/01..06-*.xml` | Cumulative policy steps, selected with the `policyStep` parameter |
| `vscode/chatLanguageModels.sample.json` | VS Code Custom Endpoint config |
| `scripts/` | `deploy.ps1`, `get-key.ps1`, `test.ps1` |

## Prerequisites

- Azure CLI + Bicep, permission to create role assignments on the Foundry account(s)
- Foundry / Azure OpenAI account(s) with a PTU deployment whose **deployment name equals the model id** you will use in VS Code (the gateway uses the OpenAI v1 API, `model` = deployment name)

## Deploy

1. Edit `infra/main.bicepparam` (APIM name, publisher, Foundry account names).
2. `./scripts/deploy.ps1 -ResourceGroup rg-apim-ghcp` — deploys with the `policyStep` in the param file.
3. Get the key: `./scripts/get-key.ps1 -ResourceGroup rg-apim-ghcp -ApimName <apim>`.

## Policy steps (apply one at a time with `-PolicyStep N`)

| Step | Adds | Why |
|---|---|---|
| 1 | Managed-identity auth to Foundry, hide upstream key | No Foundry keys on developer machines |
| 2 | `llm-token-limit` per APIM subscription | Protect PTU capacity from a single user |
| 3 | `llm-emit-token-metric` (subscription, API, model) | Chargeback/visibility in App Insights |
| 4 | Backend pool: PTU priority 1 → PAYG priority 2, circuit breaker + retry | Spillover when PTU returns 429/5xx (needs `paygAccountName`) |
| 5 | Model allow-list | Only expose approved deployments (needs `allowedModels`) |
| 6 | Reasoning-model compat: `max_tokens` → `max_completion_tokens`, drop `temperature`/`top_p`/penalties | Fixes `Unsupported parameter: 'max_tokens'` on gpt-5.x |

Test after each step: `./scripts/test.ps1 -ApimName <apim> -SubscriptionKey <key> -Model gpt-5.5`
Reproduce the `max_tokens` error (fails on steps 1–5, passes on 6): add `-SendMaxTokens`.

## VS Code

1. Command Palette → **Chat: Manage Language Models** → **Add Models** → **Custom Endpoint**, or edit `chatLanguageModels.json` directly.
2. Paste [`vscode/chatLanguageModels.sample.json`](vscode/chatLanguageModels.sample.json), replacing `<your-apim>`; enter the APIM subscription key when prompted.
3. Pick the model in the chat model picker (models need `toolCalling: true` to show for agents).

`requestHeaders.api-key` sends the key in the header APIM expects instead of `Authorization: Bearer`.

## GitHub Copilot Enterprise custom models

If the model is registered at the GitHub org/enterprise level, GitHub's servers call the endpoint, so APIM must be publicly reachable (Standard v2 gateway is by default). Point the custom model at `https://<apim>.azure-api.net/openai/v1/chat/completions` with the subscription key; policy step 6 resolves the `max_tokens` error regardless of which client sends it.

## Notes

- Streaming works; retries (step 4) only apply before the first byte is returned.
- Subscription keys are static, so per-user Entra `validate-jwt` is not used: VS Code Custom Endpoint only sends a configured key.
- Request/response bodies are not logged by the diagnostic setting (`metrics` + errors only).
- Responses API (`/v1/responses`) is exposed, but step 6 body rewriting applies to Chat Completions only.
