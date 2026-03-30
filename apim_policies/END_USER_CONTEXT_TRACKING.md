# Forward End-User Context Into Azure OpenAI Token Metrics

This policy pattern is for the case where Azure API Management sits in front of Azure OpenAI, but the real caller is an application acting on behalf of a signed-in user. In that model, the default APIM `Subscription ID` or `User ID` dimensions are often not enough for chargeback, audit, or usage reporting because they identify the application or APIM subscription rather than the human user.

Use [AOAI_Policy-Token_Tracking_End_User_Context.xml](./AOAI_Policy-Token_Tracking_End_User_Context.xml) to capture application-forwarded identity details and emit them with the Azure OpenAI token metrics.

## What The Policy Does

- Preserves the existing Azure OpenAI token limiting and metric emission pattern used in this repo.
- Adds custom metric dimensions for `End User ID`, `End User Tenant ID`, `Client Application ID`, and `Identity Source`.
- Keeps `Deployment ID` as a custom dimension so you can still break usage down by model deployment.
- Uses the APIM subscription ID as the token counter key when it exists.
- Falls back to a counter key derived from the forwarded application ID and end-user ID when APIM subscriptions are not in use.
- Removes the custom forwarding headers before the request is sent to Azure OpenAI.

## Request Contract For Calling Applications

APIM cannot infer the signed-in user behind your application unless your application forwards that context. The cleanest pattern is to project the identity data you care about into custom headers before the request reaches APIM.

### Recommended Headers

| Header | Required | Purpose | Example value | Policy fallback |
| --- | --- | --- | --- | --- |
| `x-apim-end-user-id` | Yes | Stable user identifier for reporting and chargeback. Prefer a GUID or pseudonymous internal ID. | `6f9619ff-8b86-d011-b42d-00cf4fc964ff` | `oid`, then `sub` from JWT |
| `x-apim-end-user-tenant-id` | No | Tenant identifier when you need multi-tenant reporting. | `11111111-2222-3333-4444-555555555555` | `tid` from JWT |
| `x-apim-client-application-id` | No | Calling application or client registration identifier. | `00000000-1111-2222-3333-444444444444` | `azp`, `appid`, then `client_id` from JWT |
| `x-apim-end-user-jwt` | No | Original user JWT if you want APIM to derive missing values from claims. | `eyJ0eXAiOiJKV1Qi...` | Falls back to `Authorization` if this header is absent |

### Minimal Recommendation

If you only need one additional dimension for reporting, send `x-apim-end-user-id`. That gives you per-user token tracking without forcing APIM to understand your app's identity provider.

### JWT Claim Mapping

If you choose to forward a JWT, the sample policy resolves values in this order:

| Emitted dimension | Claims used |
| --- | --- |
| `End User ID` | `oid`, then `sub` |
| `End User Tenant ID` | `tid` |
| `Client Application ID` | `azp`, then `appid`, then `client_id` |

If your token is opaque, encrypted, or not a JWT, extract the claims in your application and send the explicit headers instead.

## Important Security And Privacy Notes

- This sample parses JWT claims for observability only. It does not validate the token.
- If APIM must trust the forwarded token, add `validate-jwt` or `validate-azure-ad-token` earlier in the inbound pipeline.
- Do not send raw email addresses, display names, or other directly identifiable data unless your privacy requirements explicitly allow it.
- Prefer a stable GUID, object ID, or a one-way hashed internal user ID.
- The policy removes the custom forwarding headers before calling Azure OpenAI because Azure OpenAI does not use them.

## Cardinality Guidance

Azure Monitor custom metrics have active time-series limits. `End User ID` is intentionally a high-cardinality dimension, so keep the other custom dimensions low-cardinality.

- Good custom values: tenant IDs, application IDs, deployment IDs, source labels.
- Avoid as metric dimensions unless you truly need them: session IDs, request IDs, emails, UPNs.
- If you expect more than 50,000 active user combinations in a 12-hour period per region, consider supplementing metrics with logs.

## Example Request

```http
POST /openai/deployments/gpt-4o/chat/completions?api-version=2024-10-21 HTTP/1.1
Host: your-apim-name.azure-api.net
Content-Type: application/json
Ocp-Apim-Subscription-Key: <subscription-key>
x-apim-end-user-id: 6f9619ff-8b86-d011-b42d-00cf4fc964ff
x-apim-end-user-tenant-id: 11111111-2222-3333-4444-555555555555
x-apim-client-application-id: 00000000-1111-2222-3333-444444444444

{
  "messages": [
    {
      "role": "user",
      "content": "Summarize our Q4 support tickets."
    }
  ]
}
```

If your application already has a bearer token and wants APIM to derive missing values from that token, either:

- Send the token in `x-apim-end-user-jwt`, or
- Let APIM read the existing `Authorization: Bearer ...` header.

The custom headers are preferred because they make the contract explicit and let the application decide exactly which identity values should be logged.

## Implementation Steps

1. Add [AOAI_Policy-Token_Tracking_End_User_Context.xml](./AOAI_Policy-Token_Tracking_End_User_Context.xml) to the Azure OpenAI API or operation in APIM.
2. Replace the `backend-id` and `tokens-per-minute` values to match your environment.
3. Make sure Application Insights integration and custom metrics are enabled for the API.
4. Update your application to send at least `x-apim-end-user-id` on each Azure OpenAI request.
5. If you want APIM to derive fields from a JWT, either forward the JWT in `x-apim-end-user-jwt` or ensure the caller already presents `Authorization: Bearer ...` to APIM.
6. Use [KQL-Token_Tracking_by_End_User.kql](../kql_queries/KQL-Token_Tracking_by_End_User.kql) to validate the metrics.

## Optional Hardening

If you already authenticate callers with Microsoft Entra ID, layer token validation before metric extraction so the forwarded identity is trusted rather than merely observed.

```xml
<validate-jwt header-name="Authorization" require-scheme="Bearer" output-token-variable-name="validatedJwt">
    <openid-config url="https://login.microsoftonline.com/<tenant-id>/v2.0/.well-known/openid-configuration" />
    <audiences>
        <audience><api-app-id></audience>
    </audiences>
</validate-jwt>
```

You can then change the extraction expressions to read from the validated token instead of parsing the raw header.