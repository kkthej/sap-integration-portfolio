# Postman to SAP CI: CSRF Token Protected

An HTTPS endpoint with **CSRF protection switched on**. Callers have to fetch
a token before they can POST. Behind the endpoint, a Filter step keeps only
employees from the USA or India, and a Content Modifier wraps them in a root
element.

## Flow

```
Postman ──HTTPS (CSRF)──▶ Start ─▶ Filter 1 ─▶ Content Modifier 1 ─▶ End ──▶ response
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/CSRF_Protected` |
| Authorization | User role `ESBMessaging.send` |
| CSRF Protected | **On** |
| Max body size | 40 MB |
| Steps | Filter, then Content Modifier |
| Receiver | None, the result is the HTTP response |

## CSRF: what changes for the caller

With CSRF protection on, a POST without a valid token gets
**`403 Forbidden`** before the iFlow runs, and nothing shows up in message
monitoring. The caller has to make two requests:

**1. Fetch the token** (same URL, GET):

```
GET https://<runtime-host>/http/CSRF_Protected
Authorization: Basic <clientid:clientsecret>
X-CSRF-Token: Fetch
```

The response header `X-CSRF-Token` holds the token, and the response also
sets session cookies.

**2. Send the message** with the token **and the same cookies**:

```
POST https://<runtime-host>/http/CSRF_Protected
Authorization: Basic <clientid:clientsecret>
X-CSRF-Token: <token from step 1>
Content-Type: application/xml
```

The token is tied to the session. Postman resends the cookies automatically
when both requests are in the same cookie jar. A token copied into a client
that doesn't send the cookies is rejected with 403, even though the token
value is correct.

In Postman you can automate this with a pre-request script, or with a Tests
script on the GET that stores the token in a variable
(`pm.environment.set("csrf", pm.response.headers.get("X-CSRF-Token"))`) and
`X-CSRF-Token: {{csrf}}` on the POST.

## Step 1: Filter 1

| Setting | Value |
|---|---|
| XPath | `/employees/employee[(personal_information/nationality='USA') or (personal_information/nationality='IND')]` |
| Value type | Nodelist |

The predicate checks a child of a child (`personal_information/nationality`)
and combines two conditions with `or`.

## Step 2: Content Modifier 1

**Message Body** (Expression):

```xml
<Employees>
${in.body}
</Employees>
```

**Why this step is needed:** a Filter with **Nodelist** returns the matching
nodes one after another, **without the original root**. With more than one
match, that isn't well-formed XML, because there are several top-level
elements. Wrapping the result in a root element makes it valid again.

## Test

Request body:

```xml
<employees>
  <employee>
    <id>1</id><name>Anna</name>
    <personal_information><nationality>USA</nationality></personal_information>
  </employee>
  <employee>
    <id>2</id><name>Ravi</name>
    <personal_information><nationality>IND</nationality></personal_information>
  </employee>
  <employee>
    <id>3</id><name>Marco</name>
    <personal_information><nationality>ITA</nationality></personal_information>
  </employee>
</employees>
```

Expected response: employees 1 and 2 inside `<Employees>…</Employees>`.
Marco (ITA) is filtered out.

| Test | Expected |
|---|---|
| POST without token | `403 Forbidden`, no MPL entry |
| GET with `X-CSRF-Token: Fetch` | `200`, token in response header |
| POST with token + cookies | `200`, filtered XML |
| No USA/IND employees | `200`, `<Employees>` with nothing inside |

## Learnings

- **CSRF is checked by the adapter, not the flow.** A 403 here has no
  message processing log, so the place to look is the response, not the
  monitor.
- **The token and the session go together.** Fetch and POST must share
  cookies.
- **Nodelist filters drop the root.** Re-wrapping in a Content Modifier is
  the simplest fix.
- **When to switch CSRF on:** protection matters for browser-based callers
  that rely on session cookies. Machine-to-machine callers using OAuth
  usually run with it off. That's why the other iFlows in this repo have it
  disabled.

## Known gaps

- The input root is lowercase `<employees>/<employee>`, but the output root
  is `<Employees>`. It's valid XML but inconsistent. Pick one convention.
