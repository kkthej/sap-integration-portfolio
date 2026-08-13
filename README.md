# SAP Integration Suite — Hands-On Portfolio

Working artifacts and design notes built while preparing for
**C_CPI_2506 — SAP Certified Associate: Integration Developer**.

Everything here was built and verified on a live SAP BTP trial tenant, not
copied from tutorials. Each artifact is documented with the reasoning behind
its configuration and, where relevant, what went wrong and why.

---

## Repository structure

```
sap-integration-portfolio/
├── README.md
├── api-management/
│   ├── proxies/          exported proxy ZIPs
│   ├── providers/        backend definitions (documented — no export in UI)
│   ├── policies/         policy XML extracted from proxies
│   └── products/         published product definitions
└── cloud-integration/
    └── iflows/           integration flow artifacts
```

---

## Environment

| Item | Value |
|---|---|
| Platform | SAP BTP trial, Cloud Foundry, us10 |
| Capabilities active | Cloud Integration, API Management |
| API Management sub-features | API Modelling, Developer Hub |
| Message Queues | 20 queues / 6000 MB / 100 JMS transactions |
| Cloud Integration runtime | 8.29.18 (default profile) |
| Integration Cell | 11.3.9 (provisioned, unused) |

Role collections assigned: `Integration_Provisioner`,
`PI_Integration_Developer`, `PI_Administrator`, `PI_Business_Expert`,
`AuthGroup.API.Admin`, `AuthGroup.API.ApplicationDeveloper`.

---

## Artifacts

### API Management

| Artifact | Type | Status |
|---|---|---|
| `HelloWorldAPI` | Proxy, hardcoded URL target | Deployed, verified |
| `Sample_API_Provider` | API Provider (Internet, TLS) | Test connection 200 OK |
| `HelloWorldAPI_Provider` | Proxy, provider-linked | Deployed, verified |
| `Q_Limit` | Quota policy | Enforcement observed |
| `SpikeArrest` | Spike Arrest policy | Enforcement observed |
| `Product_Sample_01` | Product | Published to Developer Hub |

Backend for all proxies is the public Swagger Petstore service.

### Cloud Integration

Not yet started. Tenant is provisioned and the runtime is active, but no
integration flows have been deployed. This is the current gap.

---

## Design notes

Observations from building the above — the parts that only become clear by
hitting them.

### API Provider vs hardcoded URL

Two proxies were built against the same backend deliberately, one each way.

- **URL target** — the backend address is baked into the proxy at creation
  and frozen there.
- **API Provider** — host, port, TLS settings and credentials live in one
  reusable object. With **Link API Provider** enabled the proxy holds a live
  reference, so changing the provider's host propagates to every linked
  proxy on redeploy. Unticking the box copies the values in once and freezes
  them, which looks identical on day one and diverges later.

Provider is also the only route to an on-premise backend, via the
**On-Premise** type and Cloud Connector.

### The proxy is a router, not a copy of the API

Nothing declares that `/pet/{id}` exists. The runtime matches the base path,
strips it, and forwards whatever suffix remains:

```
inbound   /helloworld-p/pet/9223372036854775499
                ↓ base path stripped
suffix    /pet/9223372036854775499
                ↓ provider (host+port) + proxy URL (/v2) + suffix
outbound  https://petstore.swagger.io/v2/pet/9223372036854775499
```

Consequence: every path under the base path reaches the backend. Restricting
that requires declaring **Resources** or inspecting `proxy.pathsuffix` in a
policy.

An early call to `/pet/1` returned Petstore's own "Pet not found" error.
That was a successful proxy round trip, not a proxy failure — the gateway
relayed the backend's answer verbatim. Reading *where* an error originates
matters more than reading that one occurred.

### Policy ordering short-circuits the flow

Quota and Spike Arrest were both attached to the Proxy PreFlow. Spike Arrest
never fired, because Quota sat first in the sequence and rejected the request
before Spike Arrest was reached. Policies execute in listed order and the
first rejection ends the chain.

Best practice is the reverse of what was built here: Spike Arrest first, so
burst traffic is shed cheaply before more expensive checks — quota counter
lookups, key verification — are performed.

### Quota vs Spike Arrest

| | Quota | Spike Arrest |
|---|---|---|
| Model | Allowance over a window | Minimum interval between calls |
| Counter | Accumulates, resets at interval boundary | Nothing accumulates |
| `1pm` means | — | one call every 60 seconds |
| Protects | Business/contractual limits | Backend infrastructure from bursts |

Spike Arrest allowed 7–8 calls before rejecting, because
`maxBurstMessageCount` lets credit build during idle periods. It is not a
hard wall from a cold start.

### Quota counter scope

The violation response read `Identifier : _default` — a single global
counter shared by every caller in the world. Per-consumer quota requires
`<Identifier ref="client_id"/>`, and `client_id` is only populated by a
**Verify API Key** policy earlier in the flow. That dependency is why quota
and key verification almost always appear together.

Related fields on the Quota policy:

- `Distributed` — true keeps one shared counter across message processors.
  False lets each processor count independently, so "2 per minute" across
  four processors effectively allows eight.
- `Synchronous` — true updates the counter at check time (accurate, slower);
  false updates asynchronously (faster, permits brief overshoot).

### Consumption chain

```
API Proxy  →  Product  →  Application  →  API Key  →  Verify API Key policy
```

Consumers subscribe to Products, never to proxies. A Product can bundle
multiple proxies or a subset of one proxy's resources, which is how the same
backend is packaged as free and premium tiers.

Product-level Quota fields are metadata, not enforcement — a Quota policy
must read them via
`verifyapikey.{policyName}.apiproduct.developer.quota.limit`.

### Policy templates are copied, not linked

Applying a stored policy template inserts a copy of its policies into the
proxy. Later edits to the template do not propagate. This is the opposite of
the API Provider link, which is a live reference — a useful asymmetry to
keep straight.

### Certificates

`Trust Store` and `Key Store Certificate` were left empty on the provider
because Petstore uses a publicly trusted certificate. In a real landscape:
Trust Store holds the backend server certificates to accept; Key Store holds
the client certificate for mutual TLS.

### Provisioning-time decisions

**Message Queues** must be selected when Cloud Integration is activated. It
cannot be cleanly added afterwards without re-provisioning, which destroys
existing artifacts.

Capability activation on trial does **not** auto-assign role collections,
despite documentation implying otherwise. Every collection above was
assigned by hand, and each required a full logout/login to take effect. The
`PI_*` collections do not exist until Cloud Integration is provisioned — a
missing left navigation panel traces back to this.

### Runtime profiles

Cloud Integration is the default deployment target. **Integration Cell** is
the newer Kubernetes-based runtime for self-hosting. The long list of
**SAP Process Orchestration 7.50 SPxx** profiles exists so PI/PO customers
can develop in Cloud Integration and deploy back to on-premise PO during
migration — relevant given PI/PO mainstream maintenance ends in 2027.

---

## Terminology traps

Names that are easy to confuse and are worth separating early:

| | |
|---|---|
| **Integration Advisor** | Designs interfaces and mappings (B2B message implementation guidelines) |
| **Integration Assessment** | Governs integration strategy, powered by ISA-M |
| **Migration Assessment** | Estimates migration effort from SAP Process Orchestration |

| | |
|---|---|
| **Developer Hub** | Your own consumption portal. Formerly *API Business Hub Enterprise* |
| **SAP Business Accelerator Hub** | SAP's public catalog of prebuilt content. Formerly *SAP API Business Hub* |

| | |
|---|---|
| **Open Connectors** | Prebuilt connectivity to non-SAP cloud applications |
| **Cloud Integration adapters** | Protocol-level adapters inside an integration flow |

**Graph** is a sub-feature of API Management, not a top-level Integration
Suite capability. It exposes business data across systems as one
semantically connected graph via a single API; the artifacts are called
Business Data Graphs (BDGs). Access is OData-based, with GraphQL flagged
experimental. Requires Developer Hub as a prerequisite and the
`Graph.KeyUser` / `GraphNavigator.Viewer` role collections. Not available in
every region — absent from this tenant.

**Event Mesh** is a standalone BTP service, not an Integration Suite
capability. It does not appear in the Activate Capabilities list.

---

## Study progress

Course: *SAP Cloud Platform Integration Service Overview* (learning.sap.com)

- [x] Describing the Integration Strategy of SAP
- [x] Introducing SAP Integration Suite
- [x] Understanding API Management
- [ ] Implementing Cloud Integration
- [ ] Exploring Event Mesh

Exam areas (C_CPI_2506): SAP Integration Suite Overview · Managing APIs ·
Implementing Cloud Integration · SAP Event Mesh

---

## Next

1. Hello-world integration flow — HTTPS sender, Content Modifier, deploy,
   confirm `Started`, verify response. The Cloud Integration runtime is
   currently unverified.
2. Message mapping and content-based routing.
3. Exception subprocess and error handling.
4. JMS queue split — asynchronous decoupling across sender and processor.
5. Compose the above into a single end-to-end scenario.
