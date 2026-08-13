# Product_Sample_01

API Product published to the Developer Hub, bundling the provider-linked
Petstore proxy for external consumption.

## Configuration

### Overview

| Field | Value |
|---|---|
| Name | Product_Sample_01 |
| Title | Product_Sample_01 |
| Short Text | Product_Sample_01_Short_Text |
| Quota | *(see note — update if set)* |
| Requests Every | *(see note — update if set)* |
| Scope | (empty) |
| Description | (empty) |
| Status | Published |

### APIs

| Name | State |
|---|---|
| HelloWorldAPI_Provider | Deployed |

### Other tabs

| Tab | Value | Why |
|---|---|---|
| Permission | (none) | Restricts product visibility by developer role — only meaningful with multiple user groups |
| Rate Plans | 0 | Monetization / billing tiers — belongs to the Monetize capability |
| Custom Attribute | 0 | Arbitrary key-value pairs readable at runtime by policies for custom routing |

## Why a Product exists

A deployed API proxy is not consumable by external developers on its own.
The consumption chain is:

```
API Proxy  ->  Product  ->  Application  ->  API Key  ->  Verify API Key policy
```

- **Proxy** — routes an inbound request to a backend. Purely technical.
- **Product** — a publishable bundle of one or more proxies (or specific
  resources from a proxy), with quota and scope metadata attached.
- **Application** — created by a consumer in the Developer Hub, subscribed
  to one or more Products. Issued an Application Key and Secret.
- **API Key** — sent with each call; validated by a Verify API Key policy
  on the proxy.

Consumers subscribe to Products, never to proxies directly. This is what
allows the same backend to be sold as a free tier and a premium tier —
identical proxies, different resource subsets and quota per Product.

## Note on Product-level quota

The Quota and Requests Every fields on a Product are **metadata, not
enforcement**. They do not throttle anything by themselves.

To make them take effect, the proxy needs:

1. A **Verify API Key** policy in the Proxy PreFlow — this validates the
   caller's key and populates `client_id`.
2. A **Quota** policy that reads the product value via:
   `verifyapikey.{policyName}.apiproduct.developer.quota.limit`

Without that pairing, the number on the Product is documentation only.

This is also the difference between product-level and proxy-level quota:

| | Counter scope |
|---|---|
| Quota policy with no `<Identifier>` | One global counter shared by all callers (`Identifier : _default` in the fault response) |
| Quota policy with `<Identifier ref="client_id"/>` | One counter per subscribing application |

Observed directly during this exercise: a bare Quota policy returned
`Identifier : _default` on violation, confirming the shared counter.

## Developer Hub

Published products appear as tiles in the Developer Hub. Prerequisites
on a trial tenant:

- Developer Hub enabled as a sub-feature of the API Management capability
  (Provisioning dialog -> API Management -> Edit -> Developer Hub -> Enable)
- Role collections `AuthGroup.API.Admin` and
  `AuthGroup.API.ApplicationDeveloper` assigned to the user
- Full logout / login for role changes to take effect

Naming: **Developer Hub** was previously called **API Business Hub
Enterprise**. Distinct from **SAP Business Accelerator Hub** (formerly SAP
API Business Hub), which is SAP's public catalog of prebuilt content —
same lineage, opposite direction.