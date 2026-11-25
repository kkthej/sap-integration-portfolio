# Process Call and Local Integration Process

Splits one employee list into two filtered sets (IND and USA) by running
the same filter logic in two Local Integration Processes, then merges the
results.

## Flow

```
Integration Process
  Timer ─▶ Input Payload ─▶ Store body ─▶ Filter IND PC ─▶ Filter USA PC ─▶ End
                             (inputData)        │                │
                                                ▼                ▼
LIP "Filter the IND Employees"        LIP "Filter the USA Employees"
  Filter IND ─▶ wrap <IndEmployees>      restore ${property.inputData}
  ─▶ property IndEmps                    ─▶ Filter USA ─▶ wrap <USAEmployees>
                                         ─▶ property USAEmps
                                         ─▶ Process Call "Merging Results"
                                                       │
                                                       ▼
                                         LIP "Results"
                                           body = <FilteredEmps>
                                                    ${property.IndEmps}
                                                    ${property.USAEmps}
                                                  </FilteredEmps>
```

## Steps

| Process | Step | Type | Configuration |
|---|---|---|---|
| Main | Input Payload | Content Modifier | Constant body: 7 employees (4 IND, 3 USA) |
| Main | Store body | Content Modifier | Property `inputData` = `${in.body}` |
| Main | Filter IND PC / Filter USA PC | Process Call | Non-looping |
| IND | Filter IND Employees | Filter, Nodelist | `/employees/employee/personal_information[nationality = 'IND']` |
| IND | Adding the header | Content Modifier | Body `<IndEmployees>${in.body}</IndEmployees>` |
| IND | IndEmps | Content Modifier | Property `IndEmps` = `${in.body}` |
| USA | call body | Content Modifier | Body = `${property.inputData}` |
| USA | Filter USA Employees | Filter, Nodelist | `/employees/employee/personal_information[nationality = 'USA']` |
| USA | Adding the header / USAEmps | Content Modifier | Wrap in `<USAEmployees>`, store as `USAEmps` |
| USA | Merging Results | Process Call | Calls LIP **Results** |
| Results | Ind and USA | Content Modifier | Body `<FilteredEmps>${property.IndEmps}${property.USAEmps}</FilteredEmps>` |

## Output

```xml
<FilteredEmps>
  <IndEmployees>
    <personal_information>…Elena Rostova…</personal_information>
    <personal_information>…Priya Nair…</personal_information>
    <personal_information>…Liam O'Connor…</personal_information>
    <personal_information>…Chloe Dubois…</personal_information>
  </IndEmployees>
  <USAEmployees>
    <personal_information>…Akbar Singh…</personal_information>
    <personal_information>…Marcus Vance…</personal_information>
    <personal_information>…Carlos Mendez…</personal_information>
  </USAEmployees>
</FilteredEmps>
```

## Learnings

- **Body vs properties across process calls.** A Local Integration Process
  works on the same exchange, so headers, properties **and the body**
  carry over in both directions. After the IND LIP the body is
  `<IndEmployees>…`, which is why the USA LIP has to restore the original
  from `inputData` before filtering. The IND LIP didn't need to only
  because it ran first.
- **A Filter in Nodelist mode returns a fragment with no root.** Several
  matching nodes can't form a well-formed document on their own, so each
  result is re-wrapped in `<IndEmployees>` / `<USAEmployees>`.
- **Properties are the hand-off mechanism.** Each LIP leaves its result in
  a property, and the merge only reads properties, so the order of
  execution doesn't matter for the final body.
- **Process Call can be nested.** The USA LIP calls the Results LIP.

## Known gaps

- **`employee_id` is lost.** The XPath selects `personal_information`, the
  child, so the output has names but no IDs. Select the parent instead:
  `/employees/employee[personal_information/nationality = 'IND']`.
- **The merge is hidden inside the USA filter.** Calling Results from the
  main process after both filters (`… ─▶ Filter USA PC ─▶ Merging Results ─▶
  End`) keeps each LIP to one job and makes the flow readable from the
  main lane.
- **The two filter LIPs are duplicates** apart from the country. A single
  LIP that reads the country from a property, called twice, would remove
  the copy. It's a good next exercise for parameterising a LIP.
