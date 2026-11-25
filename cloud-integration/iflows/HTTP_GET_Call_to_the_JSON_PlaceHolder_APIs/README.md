# HTTP GET Call to the JSON PlaceHolder APIs

The first outbound call: a timer starts the flow, and an HTTP receiver
fetches a public REST resource.

## Flow

```
Timer (Run Once) ─▶ Request Reply 1 ──HTTP GET──▶ jsonplaceholder.typicode.com/users
                          │
                          ▼
                         End
```

| Item | Value |
|---|---|
| Start | Timer, Run Once (fires on every deploy) |
| Receiver adapter | HTTP, `GET https://jsonplaceholder.typicode.com/users` |
| Authentication | None (public API) |
| Send body | No (`httpShouldSendBody = false`) |
| Throw exception on failure | Yes |
| Request headers forwarded | `traceparent` only |
| Response headers kept | `*` (all) |

## Result

The response body is a JSON array of 10 users, and it becomes the message
body after Request Reply. Because the flow ends there with no receiver,
the payload is only visible in **Monitor → message → Trace** (log level
set to Trace) or as an MPL attachment.

## Learnings

- **Request Reply is the synchronous call step.** The response replaces the
  body, and the flow continues with it. A Send step (or a receiver on the
  End event) is fire-and-forget.
- **A Run Once timer fires on every deploy.** It is the quickest way to
  test outbound calls without Postman, but each redeploy produces a new
  message.
- **`allowedRequestHeaders` defaults to `traceparent`.** That's
  deliberate: without an allow-list, every internal header (including any
  you created in Content Modifiers) would be sent to the external API.
  `allowedResponseHeaders = *` does the opposite for the reply, and every
  response header from the API lands on the message.
- `throwExceptionOnFailure = true` turns a 4xx/5xx into an exception. The
  [Exception_Sub_Process](../Exception_Sub_Process) iFlow builds on this.
