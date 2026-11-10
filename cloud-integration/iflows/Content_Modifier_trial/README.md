# Content Modifier trial

Extracts three fields from an XML request using XPath and returns a reduced
XML document built only from those fields.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ XML filter ─▶ End ──▶ response
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/postman/xml` |
| Authorization | User role `ESBMessaging.send` |
| Steps | 1 Content Modifier (properties + body) |

## What the Content Modifier does

**Exchange Properties** (all type XPath, `java.lang.String`):

| Name | XPath |
|---|---|
| `P_EmpId` | `/EmployeeRequest/Employee/EmployeeId` |
| `P_EmpStatus` | `/EmployeeRequest/Employee/EmploymentStatus` |
| `P_Country` | `/EmployeeRequest/Employee/Country` |

**Message Body** (type Expression):

```xml
<Employee>
   <EmpId>${property.P_EmpId}</EmpId>
   <EmpStatus>${property.P_EmpStatus}</EmpStatus>
   <Country>${property.P_Country}</Country>
</Employee>
```

## Test

```
POST https://<runtime-host>/http/postman/xml
Content-Type: application/xml
```

```xml
<EmployeeRequest>
  <Employee>
    <EmployeeId>EMP-1001</EmployeeId>
    <FirstName>Asha</FirstName>
    <EmploymentStatus>ACTIVE</EmploymentStatus>
    <Country>IN</Country>
  </Employee>
</EmployeeRequest>
```

Response:

```xml
<Employee>
   <EmpId>EMP-1001</EmpId>
   <EmpStatus>ACTIVE</EmpStatus>
   <Country>IN</Country>
</Employee>
```

## Learnings

- A Content Modifier processes its tabs in order: headers, then
  properties, then body. That is why the body expression can read
  properties set in the same step.
- XPath runs against the body **as it was when the step started**, so
  extracting and replacing the body in one step is safe.
- This is a filter built with a Content Modifier. A Filter step or a mapping
  would do the same in a real interface. Here the point was to practise
  XPath extraction and `${property.*}` expressions.
