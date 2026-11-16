# SAP CI Filter

Practice iFlow for the **Filter** step. It takes an XML list of employees
and returns only those with a basic salary above 75,000, wrapped in a root
element.

## Flow

```
Postman ──HTTPS──▶ Start ─▶ Filter Employees ─▶ adding parent tag ─▶ End ──▶ response
```

| Item | Value |
|---|---|
| Sender adapter | HTTPS, address `/filter` |
| Authorization | User role `ESBMessaging.send` |
| CSRF Protected | On (fetch a token first, see [the CSRF iFlow](../Postman_to_SAP_CI_CSRF_Token_Protected)) |
| Steps | Filter, then Content Modifier |
| Receiver | None, the result is the HTTP response |

## Step 1: Filter Employees

| Setting | Value |
|---|---|
| XPath | `/Employees/Employee[BasicSalary > 75000]` |
| Value type | Nodelist |

`BasicSalary > 75000` is a **numeric** comparison. XPath converts the
element's text to a number before comparing, so `80000` passes and `75000`
does not (strictly greater than).

## Step 2: adding parent tag (Content Modifier)

**Message Body** (Expression):

```xml
<Employees>
${in.body}
</Employees>
```

The Filter returns only the matching `<Employee>` nodes, without
`<Employees>` around them. With two or more matches that's several
top-level elements, which isn't well-formed XML. This step puts the root
back.

## Filter value types

| Value type | Returns | Use it for |
|---|---|---|
| **Nodelist** | All matching nodes (root dropped) | Keeping several records, as here |
| **Node** | The first matching node only | Pulling out one sub-tree |
| **Boolean** | `true` / `false` | Checking whether something exists |
| **String** | Text value of the first match | A single value |
| **Integer** | Number, e.g. from `count(...)` | Counts |

## Test

Request body:

```xml
<Employees>
  <Employee><Id>1</Id><Name>Anna</Name><BasicSalary>90000</BasicSalary></Employee>
  <Employee><Id>2</Id><Name>Ravi</Name><BasicSalary>75000</BasicSalary></Employee>
  <Employee><Id>3</Id><Name>Marco</Name><BasicSalary>60000</BasicSalary></Employee>
  <Employee><Id>4</Id><Name>Lena</Name><BasicSalary>120000</BasicSalary></Employee>
</Employees>
```

Expected response: Anna and Lena only.

| Test | Expected |
|---|---|
| Salary exactly `75000` | Excluded (the comparison is `>`, not `>=`) |
| No employee above 75,000 | `<Employees>` with nothing inside |
| `BasicSalary` missing or non-numeric | Excluded (converts to `NaN`, every comparison with `NaN` is false) |

## XPath variations to try

```
/Employees/Employee[BasicSalary >= 75000]                     boundary included
/Employees/Employee[BasicSalary > 50000 and BasicSalary < 100000]   range
/Employees/Employee[Department = 'IT']                        string match
/Employees/Employee[not(BasicSalary)]                         records missing the field
/Employees/Employee[position() <= 2]                          first two records
count(/Employees/Employee[BasicSalary > 75000])               with value type Integer
```

## Learnings

- **Filter removes; it doesn't restructure.** Anything outside the matched
  nodes, including the root, is gone.
- **Boundary values need their own test.** A salary of exactly 75,000 is
  the case that tells `>` and `>=` apart.
- **Bad data drops out quietly.** Non-numeric salaries don't raise an
  error, they just disappear from the result. In a real interface, that
  needs a separate check.
