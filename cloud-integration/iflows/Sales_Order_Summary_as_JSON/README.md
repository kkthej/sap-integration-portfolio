# Sales Order Summary as JSON

Receives a multi-line XML sales order and returns a JSON summary with a
`201 Created` status and a custom response header. It is built only from
Content Modifiers, and all the aggregation is done with XPath 1.0 functions.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ Extract ─▶ Response Metadata + Technical Values ─▶ JSON Body ─▶ End
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/orders/summary` |
| Steps | 3 Content Modifiers |
| Response | `201 Created`, `Content-Type: application/json`, `X-Order-Number` |

## Step 1: Extract

| Name | Kind | XPath | Data type |
|---|---|---|---|
| `X-Order-Number` | Header | `/SalesOrder/Header/OrderNumber` | String |
| `P_Currency` | Property | `/SalesOrder/Header/Currency` | String |
| `P_CustomerId` | Property | `/SalesOrder/Header/Customer/CustomerId` | String |
| `P_CustomerName` | Property | `/SalesOrder/Header/Customer/Name` | String |
| `P_CustomerDisplay` | Property | `concat(/SalesOrder/Header/Customer/Name,' ','(',/SalesOrder/Header/Customer/CustomerId,')')` | String |
| `P_CountryCode` | Property | `translate(/SalesOrder/Header/Customer/Country, 'abc…z', 'ABC…Z')` | String |
| `P_ItemCount` | Property | `count(/SalesOrder/Items/Item)` | Integer |
| `P_TotalQuantity` | Property | `sum(/SalesOrder/Items/Item/Quantity)` | Integer |
| `P_OrderTotal` | Property | `sum(/SalesOrder/Items/Item/LineTotal)` | Double |
| `P_FirstMaterial` | Property | `/SalesOrder/Items/Item[1]/Material` | String |
| `P_LastMaterial` | Property | `/SalesOrder/Items/Item[last()]/Material` | String |
| `P_OrderDate` | Property | ⚠ `${date:now:yyyy-MM-dd}`, see Known gaps | – |

**Why the order number is the only header:** it's the one value that must
leave the iFlow as an HTTP response header. Naming it `X-Order-Number`
directly means no rename or delete step is needed. Everything else is
internal working data, so it lives in properties and never reaches the
caller.

## Step 2: Response metadata and technical values

| Name | Kind | Type | Value |
|---|---|---|---|
| `Content-Type` | Header | Constant | `application/json` |
| `CamelHttpResponseCode` | Header | Constant | `201` |
| `P_Status` | Property | Constant | `RECEIVED` |
| `P_ReceivedAt` | Property | Expression | `${date:now:yyyy-MM-dd'T'HH:mm:ss'Z'}` |

`CamelHttpResponseCode` isn't sent as a header. The HTTPS sender turns it
into the HTTP status line.

## Step 3: JSON body

```json
{
  "orderNumber": "${header.X-Order-Number}",
  "orderDate": "${property.P_OrderDate}",
  "customer": "${property.P_CustomerDisplay}",
  "country": "${property.P_CountryCode}",
  "itemCount": ${property.P_ItemCount},
  "totalQuantity": ${property.P_TotalQuantity},
  "orderTotal": ${property.P_OrderTotal},
  "currency": "${property.P_Currency}",
  "firstMaterial": "${property.P_FirstMaterial}",
  "lastMaterial": "${property.P_LastMaterial}",
  "receivedAt": "${property.P_ReceivedAt}",
  "status": "${property.P_Status}"
}
```

Numeric fields are left unquoted so they are JSON numbers.

## Test results

| Test | Items | itemCount | totalQuantity | orderTotal | first / last | Result |
|---|---|---|---|---|---|---|
| Base order | 3 | 3 | 17 | `445.0` | MAT-100 / MAT-300 | ✔ |
| Decimal line total (`45.50`) | 3 | 3 | 17 | `445.5` | MAT-100 / MAT-300 | ✔ |
| Single item | 1 | 1 | 3 | `36.0` | MAT-500 / MAT-500 | ✔ |
| Six items | 6 | 6 | 28 | `585.09` | MAT-100 / MAT-600 | ✔ |
| Empty `<Items/>` | 0 | 0 | 0 | `0.0` | "" / "" | ✔ valid JSON |

Response headers verified in Postman: `201 Created`,
`Content-Type: application/json`, `X-Order-Number: SO-45006`. No internal
headers leak. The remaining headers (`Sap_messageprocessinglogid`,
`X-Vcap-Request-Id`, security and cache headers) are added by the CPI
runtime and the Cloud Foundry router after the iFlow ends.

## Bugs found and fixed during testing

1. **Wrong field summed.** The first version summed `UnitPrice`, giving `12`
   for a one-item order instead of `36`, and `174` for the base order
   instead of `445`.
2. **Silent truncation.** The `174` should have been `174.5`: the row was
   typed `java.lang.Integer`, which dropped the decimal without an error.
   Money must never be Integer. It was changed to Double.
3. **Ambiguous timestamp.** `receivedAt` was UTC but carried no time
   zone. Adding `'Z'` to the pattern fixed it.

## Learnings

- **XPath 1.0 `sum()` returns a double.** The data type in the Content
  Modifier decides how it's rendered: Integer truncates (`174`), Double
  prints `445.0`, String prints the XPath string value (`445`). None of
  them gives `445.00`. XPath 1.0 has no number formatting, so fixed
  decimals need a mapping or script.
- **Double is binary floating point.** Some decimal sums can come out as
  `0.30000000000000004`. Real interfaces keep amounts as strings or use a
  decimal type.
- **`[last()]` vs `[3]`.** Only the six-item test proves the predicate is
  dynamic. A three-item test passes either way.
- **Empty sets are safe here.** `count()` and `sum()` return `0` on an
  empty node set, so the unquoted numeric fields stay valid JSON. Missing
  strings become `""` inside quotes, which is also valid.

## Known gaps

- **`orderDate` is not read from the payload.** `P_OrderDate` is
  `${date:now:yyyy-MM-dd}`, so it holds today's date, not the order's
  date. Every test passed only because the test orders were dated today.
  The fix is to change it to XPath `/SalesOrder/Header/OrderDate`. Test it
  with an order dated `2026-01-15`.
- Steps 1 and 2 overwrite the body with a debug list of values. That's
  harmless, because step 3 replaces it, but it can be removed.
