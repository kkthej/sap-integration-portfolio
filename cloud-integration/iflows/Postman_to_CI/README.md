# Postman to CI

First end-to-end round trip: a plain-text request from Postman, modified in
Cloud Integration, returned to the caller.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ Content Modifier 1 ─▶ End ──▶ response to Postman
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/postman/text` |
| Authorization | User role `ESBMessaging.send` |
| Steps | 1 Content Modifier (body only) |
| Receiver | None, the modified body is the HTTP response |

## What the Content Modifier does

**Message Body** (type Expression):

```
CPI received:

 ${in.body}
```

`${in.body}` is the incoming payload, so the response echoes the request
with a prefix.

## Test

```
POST https://<runtime-host>/http/postman/text
Authorization: Basic <clientid:clientsecret of an integration-flow service key>
Content-Type: text/plain

hello
```

Response:

```
CPI received:

 hello
```

## Learnings

- With no receiver, the HTTPS sender is synchronous: whatever the body is at
  the End event goes back to the caller.
- The endpoint is on the **runtime** host (`...cfapps...`), not the design
  host, and is called with credentials from a Process Integration Runtime
  `integration-flow` service key, not your BTP user.
