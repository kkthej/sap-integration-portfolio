# Sample_API_Provider

| Field | Value |
|---|---|
| Type | Internet |
| Host | petstore.swagger.io |
| Port | 443 |
| Use SSL | Yes |
| Trust Store | (default — public CA) |
| Key Store Certificate | (none) |
| Catalog Service Settings | not used |

Test Connection: 200 OK

## Notes
- Type=Internet routes directly. Type=On-Premise routes via Cloud Connector.
- Catalog Service Settings only apply to SAP OData catalog backends
  (S/4HANA, Gateway) where services can be browsed. Left empty here.
- Trust Store / Key Store Certificate empty because Petstore uses a
  publicly-trusted cert. A backend behind corporate PKI needs both:
  Trust Store for the server cert, Key Store for mutual TLS.
- Consumed by HelloWorldAPI_Provider with Link API Provider enabled,
  so host changes propagate on redeploy.