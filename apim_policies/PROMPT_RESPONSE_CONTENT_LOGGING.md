# Capture Prompt And Response Content In APIM

This sample shows how to capture the text a caller sends to Azure OpenAI through API Management and the text that comes back from the model. The policy writes both sides of the exchange into Application Insights trace telemetry so you can query it later from Application Insights Logs or the connected Log Analytics workspace.

Use [AOAI_Policy-Trace_Prompt_Response_Content.xml](./AOAI_Policy-Trace_Prompt_Response_Content.xml) when you want observability over prompt and response content without introducing a separate Event Hub ingestion pipeline.

## What The Policy Logs

- Inbound request content before APIM forwards the request to Azure OpenAI.
- Outbound model response content before APIM returns the response to the caller.
- Correlation metadata so request and response traces can be paired later:
  - `APIMRequestId`
  - `DeploymentId`
  - `EndUserId`
  - `CapturePhase`
  - `StreamRequested`
  - `OriginalChars`
  - `Truncated`

For common Azure OpenAI JSON payloads, the policy tries to normalize content into readable text:

- Request bodies: `messages`, `input`, or `prompt`
- Response bodies: `choices[].message.content`, `choices[].text`, `output_text`, or `output[].content[].text`

If the payload does not match those shapes, the policy falls back to logging the raw body text.

## Prerequisites

This policy depends on Application Insights integration for APIM.

1. Ensure APIM already has an Application Insights logger configured.
2. Enable Application Insights diagnostic logging on the Azure OpenAI API or on All APIs.
3. Make sure the diagnostic verbosity allows `information` traces.
4. If you want the trace data in Log Analytics, use a workspace-based Application Insights resource or query the connected workspace.

This repo already provisions an Application Insights logger in the APIM deployment modules at [modules/api-management.bicep](../modules/api-management.bicep#L35) and [modules/api-management-private.bicep](../modules/api-management-private.bicep#L41).

## How The Policy Works

### Inbound

- Reads the request body with `preserveContent: true` so APIM can still forward it.
- Detects whether the request asked for streaming by checking the `stream` property in the JSON body.
- Extracts prompt text when possible and writes it as an Application Insights trace with `CapturePhase = inbound-request`.

### Outbound

- If the request was not streaming, reads the response body with `preserveContent: true`.
- Extracts the model response text when possible and writes it as an Application Insights trace with `CapturePhase = outbound-response`.
- If the request was streaming, it does not attempt to buffer or reconstruct the response body. Instead it writes a trace with `CapturePhase = outbound-response-skipped`.

## Size Limits And Truncation

There are two practical limits to keep in mind:

- Application Insights maximum telemetry item size: `64 KB`
- Application Insights maximum trace message length: `32,768` characters

The sample policy truncates captured content to `32,000` characters and records the following metadata:

- `OriginalChars`: length before truncation
- `Truncated`: whether truncation occurred

This keeps the trace item under the documented Application Insights limits while leaving space for metadata and envelope overhead.

## Security, Privacy, And Compliance Gotchas

- Prompts and responses often contain sensitive data, PII, secrets, regulated content, or internal business data.
- Anyone who can query `AppTraces` can potentially read the captured prompt and response content.
- Retention and access control on the Application Insights workspace become part of your data governance boundary.
- This pattern is for observability and troubleshooting. It is not a substitute for a dedicated audit archive.
- If your organization has strict data minimization requirements, redact or hash values before they reach APIM, or narrow the extracted fields before logging.

## Performance Gotchas

- APIM body capture requires reading the payload in the policy pipeline.
- Microsoft documents that body logging can materially reduce throughput on high-volume APIs.
- The `trace` policy itself is not affected by Application Insights sampling, so every invocation of this policy is logged when diagnostics are enabled for the API.
- If you need to capture every full request and response at larger sizes or higher sustained volume, prefer Event Hub plus downstream storage over Application Insights traces.

## Streaming Gotchas

Streaming is the main edge case.

- The sample still logs the inbound prompt content for streaming requests.
- The sample intentionally skips outbound response body capture when `stream: true` is present in the request payload.
- This avoids turning a streamed response into a buffered response path inside APIM.

If you need full streaming transcript capture, use a downstream application log or an Event Hub based capture pipeline instead of trying to reconstruct the streamed chunks inside this policy.

## End-User Correlation

If your application already forwards end-user identity headers, this policy records `x-apim-end-user-id` as `EndUserId`. If that header is absent, it falls back to the APIM user ID when available.

You can combine this policy with [END_USER_CONTEXT_TRACKING.md](./END_USER_CONTEXT_TRACKING.md) when you want both token metrics and content traces tied back to an application user.

## Querying In Application Insights And Log Analytics

The traces land in the `AppTraces` table in Log Analytics. They do not become queryable inside Azure OpenAI itself. Query the Application Insights Logs experience or the linked Log Analytics workspace.

Use [KQL-Prompt_Response_Content_Logging.kql](../kql_queries/KQL-Prompt_Response_Content_Logging.kql) for sample queries.

### Most Recent Prompt And Response Traces

```kql
AppTraces
| where tostring(Properties["ContentLogging"]) == "true"
| extend Phase = tostring(Properties["CapturePhase"])
| project TimeGenerated, Phase, RequestId = tostring(Properties["APIMRequestId"]), DeploymentId = tostring(Properties["DeploymentId"]), EndUserId = tostring(Properties["EndUserId"]), Truncated = tostring(Properties["Truncated"]), Message
| order by TimeGenerated desc
```

### Pair Request And Response By APIM Request ID

```kql
let contentLogs = AppTraces
| where tostring(Properties["ContentLogging"]) == "true"
| extend Phase = tostring(Properties["CapturePhase"]), RequestId = tostring(Properties["APIMRequestId"]), DeploymentId = tostring(Properties["DeploymentId"]), EndUserId = tostring(Properties["EndUserId"])
| project TimeGenerated, Phase, RequestId, DeploymentId, EndUserId, Message, OperationId;
contentLogs
| summarize Messages = make_bag(pack(Phase, Message)), FirstSeen = min(TimeGenerated), LastSeen = max(TimeGenerated), DeploymentId = take_any(DeploymentId), EndUserId = take_any(EndUserId) by RequestId, OperationId
| project LastSeen, RequestId, OperationId, DeploymentId, EndUserId, RequestPrompt = tostring(Messages["inbound-request"]), ModelResponse = tostring(Messages["outbound-response"]), SkippedResponseNotice = tostring(Messages["outbound-response-skipped"])
| order by LastSeen desc
```

## When To Use Event Hub Instead

Use Event Hub instead of Application Insights traces when you need one or more of the following:

- payloads larger than the Application Insights trace limits
- guaranteed capture for a high-volume API with downstream archival
- long-term audit storage separated from operational telemetry
- enrichment and routing into other systems before storage

For this repo, the trace-based sample is the lighter-weight option because it reuses the Application Insights integration that is already part of the APIM deployment.

## Implementation Steps

1. Add [AOAI_Policy-Trace_Prompt_Response_Content.xml](./AOAI_Policy-Trace_Prompt_Response_Content.xml) to the Azure OpenAI API or operation in APIM.
2. Confirm Application Insights diagnostics are enabled for that scope.
3. Verify the diagnostic verbosity includes `information` traces.
4. Run a non-streaming request through APIM and validate that both `inbound-request` and `outbound-response` traces appear in `AppTraces`.
5. Run a streaming request and validate that you see `inbound-request` and `outbound-response-skipped`.