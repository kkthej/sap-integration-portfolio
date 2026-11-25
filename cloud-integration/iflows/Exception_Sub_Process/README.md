# Exception Sub Process

Deliberately calls a URL that returns 404, catches the failure in an
Exception Subprocess, and emails the error text through the Mail adapter
(Gmail SMTP).

## Flow

```
Timer (Run Once) ─▶ Content Modifier 1 ─▶ Request Reply 1 ─▶ End ──Mail──▶ success mail
                                              │
                                              └─HTTP GET─▶ jsonplaceholder.typicode.com/users/1/test  (404)

Exception Subprocess 1:
  Error Start 1 ─▶ Send 1 ──Mail──▶ failure mail ─▶ End 1
```

| Item | Value |
|---|---|
| Start | Timer, Run Once |
| Content Modifier 1 | Constant body `Testing CI for gmail adapter` |
| Request Reply 1 | HTTP `GET https://jsonplaceholder.typicode.com/users/1/test`, throw exception on failure |
| End event receiver | Mail, subject `test mail adapter1`, body `${in.body}` |
| Exception Subprocess → Send 1 | Mail, subject `Interface exception sub process got Failed`, body `${property.CamelExceptionCaught}` |
| Mail server | `smtp.gmail.com:465`, SMTPS, auth `loginPlain` |
| Credentials | Security Material alias `GmailCredentials` (User Credentials with a Gmail **app password**) |

## What happens at runtime

1. The Content Modifier sets a body.
2. Request Reply calls `/users/1/test`, which doesn't exist, so the API
   returns **404**.
3. `throwExceptionOnFailure = true` turns the 404 into an exception, so
   the main flow stops and the success mail is never sent.
4. The Exception Subprocess starts. `CamelExceptionCaught` holds the
   exception, which for the HTTP adapter includes the status code and
   response, and it's emailed.

To see the happy path, change the URL to `/users/1` and redeploy: the
success mail arrives with the user JSON as its body.

## Learnings

- **`${property.CamelExceptionCaught}`** is the standard way to get the
  error text into an alert. `${exception.message}` gives just the message,
  and `${exception.stacktrace}` the full trace.
- **A Local Integration Process can have its own exception subprocess.**
  If it does, errors inside that LIP are handled there. If it doesn't, the
  error propagates back to the calling process and its exception
  subprocess. `Local Integration Process 1` here has `Exception
  Subprocess 2` but is never called, so it never runs.
- **How it ends decides the MPL status.** Ending the subprocess with a
  plain End event versus an **Error End** event changes what Monitor
  shows. Error End keeps the message as *Failed*, which is usually what
  operations wants: an alert mail **plus** a failed message they can
  search for. Check which status this flow produces in Monitor and record
  it here.
- **Gmail needs an app password**, not the account password. The SMTP
  adapter authenticates with the credential alias, so the password never
  appears in the iFlow.

## Known gaps

- `Local Integration Process 1` is an empty leftover (Start → End) that's
  never called. It can be deleted.
- Both mail channels have an attachment row (`text/html`, source Body).
  Check whether the received mails carry the body as an attachment as well
  as in the text, and remove the row if that isn't wanted.
