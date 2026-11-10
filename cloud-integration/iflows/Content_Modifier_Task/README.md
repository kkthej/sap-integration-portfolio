# Content Modifier Task

**Employee Integration Acknowledgement Using Content Modifier Only**

Receives an employee master record, extracts business fields, enriches them
with technical metadata, and returns a structured acknowledgement. It is
built entirely from Content Modifiers, with no script or mapping.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ Extract ─▶ Adding Technical Values ─▶ Final Responce ─▶ End ──▶ response
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/PostmanToCI` |
| Authorization | User role `ESBMessaging.send` |
| Steps | 3 Content Modifiers |

## Step 1: Extract

**Message Headers** (XPath):

| Name | XPath |
|---|---|
| `H_RequestId` | `/EmployeeRequest/RequestInfo/RequestId` |
| `H_SourceSystem` | `/EmployeeRequest/RequestInfo/SourceSystem` |

**Exchange Properties** (XPath, `java.lang.String`):

| Name | XPath |
|---|---|
| `P_EmployeeId` | `/EmployeeRequest/Employee/EmployeeId` |
| `P_FirstName` | `/EmployeeRequest/Employee/FirstName` |
| `P_LastName` | `/EmployeeRequest/Employee/LastName` |
| `P_Department` | `/EmployeeRequest/Employee/Department` |
| `P_Country` | `/EmployeeRequest/Employee/Country` |
| `P_EmploymentStatus` | `/EmployeeRequest/Employee/EmploymentStatus` |
| `P_BasicSalary` | `/EmployeeRequest/Employee/BasicSalary` |

The body is rebuilt from these values in the original structure.

## Step 2: Adding Technical Values

**Exchange Properties**:

| Name | Type | Value |
|---|---|---|
| `P_CorrelationID` | Expression | `${header.H_RequestId}-${property.P_EmployeeId}-${date:now:HH:mm:ss}` |
| `P_CompleteName` | Expression | `${property.P_FirstName} ${property.P_LastName}` |
| `P_ProcessingDate` | Expression | `${date:now:yyyy-MM-dd}` |
| `P_ProcessingTime` | Expression | `${date:now:HH:mm:ss}` |
| `P_ExchangeId` | Expression | `${exchangeId}` |
| `P_MessageId` | Expression | `${id}` |
| `P_Currency` | Constant | `INR` |
| `P_Environment` | Constant | `TRAINING` |
| `P_ProcessingStatus` | Constant | `ACCEPTED` |
| `P_InterfaceName` | Constant | `Employee_Master_Integration` |
| `P_TargetSystem` | Constant | `SAP_S4HANA` |

## Step 3: Final Responce

The body is replaced with an `EmployeeAcknowledgement` document in five
sections: `TechnicalInformation`, `SourceInformation`,
`EmployeeInformation`, `SalaryInformation` and `ProcessingResult`. Every
field is filled from the headers and properties above.

## Test

```
POST https://<runtime-host>/http/PostmanToCI
Content-Type: application/xml
```

```xml
<EmployeeRequest>
  <RequestInfo>
    <RequestId>REQ-5001</RequestId>
    <SourceSystem>WORKDAY</SourceSystem>
  </RequestInfo>
  <Employee>
    <EmployeeId>EMP-1001</EmployeeId>
    <FirstName>Asha</FirstName>
    <LastName>Rao</LastName>
    <Department>Finance</Department>
    <Country>IN</Country>
    <EmploymentStatus>ACTIVE</EmploymentStatus>
    <BasicSalary>85000</BasicSalary>
  </Employee>
</EmployeeRequest>
```

Response (abridged):

```xml
<EmployeeAcknowledgement>
  <TechnicalInformation>
    <MessageId>...</MessageId>
    <ExchangeId>...</ExchangeId>
    <CorrelationId>REQ-5001-EMP-1001-01:42:24</CorrelationId>
    <InterfaceName>Employee_Master_Integration</InterfaceName>
    ...
  </TechnicalInformation>
  <EmployeeInformation>
    <CompleteName>Asha Rao</CompleteName>
    ...
  </EmployeeInformation>
  <ProcessingResult><Status>ACCEPTED</Status>...</ProcessingResult>
</EmployeeAcknowledgement>
```

## Design notes

- **Headers vs properties.** The two request-level IDs are headers and
  everything else is a property. Headers travel with the message to
  receivers and, on a synchronous HTTPS sender, back to the caller as
  response headers. Properties stay inside the exchange. Business data such
  as salary belongs in properties, not headers.
- **Splitting the work into three steps** keeps each step to one
  responsibility: extract, enrich, build output. It also makes trace mode
  readable, because each step shows only what it changed.
- **Message ID vs exchange ID.** `${id}` is the message ID and
  `${exchangeId}` is the Camel exchange ID. In a simple flow like this one
  they usually match. They diverge after splits and multicasts.
- **Known gaps:**
  - The `ProcessingResult/Description` text is hardcoded
    (`EMP-1001 from WORKDAY`). It should be built from properties:
    `Employee ${property.P_EmployeeId} from ${header.H_SourceSystem} was
    accepted for ${property.P_TargetSystem} processing`.
  - `P_CorrelationID` uses second precision, so two requests with the same
    IDs in the same second collide.
  - The Extract step rebuilds the body unchanged, so its body section can be
    removed without changing the result.
