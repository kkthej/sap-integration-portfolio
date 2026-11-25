# test

Scratch iFlow used to try out HTTPS sender settings. It isn't a finished
exercise.

| Item | Value |
|---|---|
| Sender | HTTPS, address `/test`, role `ESBMessaging.send` |
| CSRF protection | Off |
| Maximum body size | 40 MB |
| Steps | 1 Content Modifier with an empty constant body |

Calling `POST /http/test` returns an empty `200` response.

The **Maximum Body Size** setting on the HTTPS sender rejects larger
requests before the iFlow starts, with `413 Payload Too Large`. This is
the place to cap what callers can push into the tenant.

> Candidate for deletion from the tenant once the experiment is done.
> After that, run the sync and remove this folder in the same commit.
