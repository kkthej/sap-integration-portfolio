# SOAP-style Purchase Order with XML Namespaces

**Scenario:** a supplier portal sends a purchase order as namespaced XML.
Some fields are optional. Operations must be able to change the target
system without editing the iFlow.

The iFlow reads the namespaced fields, fills in defaults for missing
optional fields, takes routing values from **externalized parameters**, and
returns a namespaced acknowledgement that includes the original request.
It uses only Content Modifiers.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ EXTRACT + KEEP ORIGINAL ─▶ CONFIGURATION + DERIVED VALUES ─▶ BODY ─▶ End
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/po/ack` |
| Authorization | User role `ESBMessaging.send` |
| CSRF Protected | Off |
| Namespace mapping (Runtime Configuration) | `xmlns:po=urn:acme:procurement:po:v1;xmlns:addr=urn:acme:common:address:v1` |
| Steps | 3 Content Modifiers |
| Response | `application/xml`, namespace `urn:acme:procurement:ack:v1` |

## Namespace mapping

The incoming document uses two namespaces: one for the purchase order and
one for the shared address type. An XPath like `/PurchaseOrderRequest/...`
**finds nothing** against namespaced XML. Elements have to be addressed with
a prefix, and the prefix has to be declared in the iFlow's **Runtime
Configuration → Namespace Mapping**:

```
xmlns:po=urn:acme:procurement:po:v1;xmlns:addr=urn:acme:common:address:v1
```

What matters is the **namespace URI**, not the prefix. The sender could
use `p:` or a default namespace. As long as the URI matches, `po:` in the
iFlow resolves to the same elements.

## Step 1: EXTRACT + KEEP ORIGINAL

| Property | Type | Value |
|---|---|---|
| `OriginalRequest` | Expression | `${in.body}` |
| `PONumber` | XPath | `/po:PurchaseOrderRequest/po:Header/po:PONumber` |
| `Plant` | XPath | `/po:PurchaseOrderRequest/po:Header/po:Plant` |
| `Buyer` | XPath | `if (normalize-space(/po:PurchaseOrderRequest/po:Header/po:Buyer)) then normalize-space(...) else 'UNASSIGNED'` |
| `Priority` | XPath | `if (normalize-space(/po:PurchaseOrderRequest/po:Header/po:Priority)) then normalize-space(...) else 'NORMAL'` |
| `SupplierId` | XPath | `/po:PurchaseOrderRequest/po:Supplier/po:SupplierId` |
| `SupplierName` | XPath | `/po:PurchaseOrderRequest/po:Supplier/po:Name` |
| `City` | XPath | `/po:PurchaseOrderRequest/po:Supplier/addr:Address/addr:City` |
| `PostalCode` | XPath | `/po:PurchaseOrderRequest/po:Supplier/addr:Address/addr:PostalCode` |
| `SupplierCountry` | XPath | `/po:PurchaseOrderRequest/po:Supplier/addr:Address/addr:Country` |
| `DeliveryDate` | XPath | `/po:PurchaseOrderRequest/po:DeliveryDate` |

All values are typed `java.lang.String`. Message body is set to
`${property.OriginalRequest}`.

**Optional fields.** `Buyer` and `Priority` handle three cases with one
expression:

| Input | `normalize-space()` | Result |
|---|---|---|
| `<po:Priority>HIGH</po:Priority>` | `HIGH` (truthy) | `HIGH` |
| `<po:Priority>   </po:Priority>` | `""` (falsy) | `NORMAL` |
| element missing | `""` (falsy) | `NORMAL` |

The Content Modifier's **Default** column only applies when the XPath finds
no node. It would miss the "present but blank" case, which is why the
condition is written into the XPath. `if … then … else` is XPath 2.0
syntax; XPath 1.0 has no conditional expression.

**Why keep the original:** the body is saved to a property **before**
anything changes it, so it can be returned in the acknowledgement for
traceability.

## Step 2: CONFIGURATION + DERIVED VALUES

| Property | Type | Value |
|---|---|---|
| `TargetSystem` | Constant | `{{TargetSystem}}` |
| `Environment` | Constant | `{{Environment}}` |
| `SenderComponent` | Constant | `{{SenderComponent}}` |
| `SupplierDisplay` | Expression | `${property.SupplierName} (${property.SupplierId}), ${property.City} ${property.PostalCode} ${property.SupplierCountry}` |
| `ProcessedAt` | Expression | `${date:now:yyyy-MM-dd HH:mm:ss}` |

**Externalized parameters.** `{{...}}` values are placeholders. They are
filled in under **Configure** on the deployed iFlow, so the target system
can be changed and redeployed without opening the editor. That's the
"operations must change the target without editing the iFlow" requirement.

Current values (`parameters.prop`):

| Parameter | Value |
|---|---|
| `TargetSystem` | `SAP_ECC` |
| `Environment` | `TRAINING` |
| `SenderComponent` | `SUPPLIER_PORTAL` |

## Step 3: BODY

Header `Content-Type: application/xml`. Message body (Expression):

```xml
<ack:PurchaseOrderAck xmlns:ack="urn:acme:procurement:ack:v1">
    <ack:PONumber>${property.PONumber}</ack:PONumber>
    <ack:Plant>${property.Plant}</ack:Plant>
    <ack:Buyer>${property.Buyer}</ack:Buyer>
    <ack:Priority>${property.Priority}</ack:Priority>
    <ack:Supplier>${property.SupplierDisplay}</ack:Supplier>
    <ack:DeliveryDate>${property.DeliveryDate}</ack:DeliveryDate>
    <ack:ProcessedAt>${property.ProcessedAt}</ack:ProcessedAt>
    <ack:Routing>
        <ack:Sender>${property.SenderComponent}</ack:Sender>
        <ack:Target>${property.TargetSystem}</ack:Target>
        <ack:Environment>${property.Environment}</ack:Environment>
    </ack:Routing>
    <ack:OriginalRequest><![CDATA[${property.OriginalRequest}]]></ack:OriginalRequest>
</ack:PurchaseOrderAck>
```

The original request goes inside **CDATA**, so its XML is carried as text
and doesn't clash with the response's own structure or namespaces.

## Test

```
POST https://<runtime-host>/http/po/ack
Content-Type: application/xml
```

```xml
<po:PurchaseOrderRequest xmlns:po="urn:acme:procurement:po:v1"
                         xmlns:addr="urn:acme:common:address:v1">
  <po:Header>
    <po:PONumber>PO-2026-0815</po:PONumber>
    <po:Plant>1010</po:Plant>
    <po:Buyer>M. Rossi</po:Buyer>
    <po:Priority>HIGH</po:Priority>
  </po:Header>
  <po:Supplier>
    <po:SupplierId>SUP-4471</po:SupplierId>
    <po:Name>Acme Components</po:Name>
    <addr:Address>
      <addr:City>Torino</addr:City>
      <addr:PostalCode>10126</addr:PostalCode>
      <addr:Country>IT</addr:Country>
    </addr:Address>
  </po:Supplier>
  <po:DeliveryDate>2026-12-01</po:DeliveryDate>
</po:PurchaseOrderRequest>
```

| Test | Change to the payload | Expected |
|---|---|---|
| Full order | none | All fields filled, `Priority` = `HIGH` |
| Optional fields missing | delete `Buyer` and `Priority` | `UNASSIGNED` / `NORMAL` |
| Optional fields blank | `<po:Priority>  </po:Priority>` | `NORMAL` |
| Different prefix, same URI | rename `po:` to `p:` throughout | Same result |
| Wrong namespace URI | change `…po:v1` to `…po:v2` | Extracted fields empty, `Buyer`/`Priority` fall back to defaults |
| Change the target | Configure → `TargetSystem` = `SAP_S4HANA`, redeploy | `<ack:Target>SAP_S4HANA</ack:Target>` |

## Learnings

- **Namespaces are matched by URI, not prefix.** A missing namespace
  mapping doesn't raise an error. Every XPath just returns empty.
- **The Default column misses blank elements.** It only applies when no
  node is found. `normalize-space()` with a conditional covers both missing
  and blank.
- **Capture the original first.** Once a Content Modifier replaces the
  body, the original is gone unless it was saved to a property.
- **Externalize anything operations may change.** Hardcoded routing values
  mean a design-time change and a redeploy from the editor.

## Known gaps

- **`ProcessedAt` has no time zone.** The runtime clock is UTC, so a
  reader in Italy can't tell. Use `yyyy-MM-dd'T'HH:mm:ss'Z'`, as in the
  Sales Order iFlow.
- **`SupplierDisplay` breaks when address fields are missing.** You get
  double spaces or a trailing `, `. It needs the same conditional treatment
  as `Buyer`.
- **`DeliveryDate` and `PONumber` aren't validated.** A PO without a
  number is acknowledged as if it were fine.
- **Leftover parameter `Ta`** (`SAP_S4HANA`) in `parameters.prop` isn't
  referenced by any step. It's probably a typo of `TargetSystem` and can be
  removed.
