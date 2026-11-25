# SAP CI Router and Externalize the Parameters

Routes a message down one of two branches based on an **externalized
parameter**, so the routing decision can change through *Configure*
without editing the iFlow.

## Flow

```
Timer ─▶ Input Payload ─▶ Data? (Router) ──Route 2: Sent_To_Receiver = 'Y'──▶ data available ─▶ End 1
                                       └─Route 1 (default)───────────────▶ Data not available ─▶ End
```

| Step | Configuration |
|---|---|
| Input Payload | Constant body (one `Employee`), property `Sent_To_Receiver` = `{{Sent_To_Receiver}}` |
| Data? | Router (Exclusive Gateway), throw exception if no route = false |
| Route 2 | Non-XML condition `${property.Sent_To_Receiver} = 'Y'` |
| Route 1 | Default route |
| data available / Data not available | Content Modifier, constant body `emps available` / `no emps` |

Externalized parameter (in `parameters.prop`):

```
Sent_To_Receiver=Y
```

## Test

| `Sent_To_Receiver` (set via Configure) | Route taken | Final body |
|---|---|---|
| `Y` | Route 2 | `emps available` |
| `N` (or anything else) | Route 1, default | `no emps` |

The change takes effect after **Configure → Save → Deploy**. No edit of
the iFlow and no new version are needed.

## Learnings

- **`{{param}}` makes a value configurable per tenant.** In a real
  landscape the same iFlow version moves DEV → QA → PRD, and only the
  configured values differ. Plain constants would force an edit and a new
  version per system.
- **Non-XML vs XML conditions.** A Router condition is either XPath on the
  body (XML) or a Camel Simple expression on headers/properties (non-XML).
  This flow uses non-XML because the decision doesn't depend on the
  payload.
- **Always have a default route.** It is the safety net when no condition
  matches. Without one, the "throw exception" setting decides whether an
  unmatched message fails or is silently dropped.
- **Conditions are evaluated in order.** The first match wins, so
  overlapping conditions need the most specific one first.

## Known gaps

- The payload (an `Inactive` employee) isn't used by the routing. A more
  realistic version would route on the payload itself, for example XPath
  `/Employees/Employee/EmploymentStatus = 'Active'`, and keep the
  externalized flag as a global on/off switch.
