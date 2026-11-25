# Converters In SAP CI

Fetches a JSON object from a REST API and converts it to XML, so that
XML-based steps (XPath, Filter, Router, mapping) can work on it.

## Flow

```
Timer (Run Once) ─▶ Request Reply 1 ─▶ JSON to XML Converter 1 ─▶ End
                         │
                         └──HTTP GET──▶ jsonplaceholder.typicode.com/users/6
```

| Item | Value |
|---|---|
| Start | Timer, Run Once |
| Receiver | HTTP, `GET https://jsonplaceholder.typicode.com/users/6`, no auth |
| Converter | JSON to XML |
| Add XML root element | Yes, name `root` |
| Use namespace mapping | Yes, separator `:` (no mapping defined) |

## Example

Response from the API (abridged):

```json
{
  "id": 6,
  "name": "Mrs. Dennis Schulist",
  "username": "Leopoldo_Corkery",
  "email": "Karley_Dach@jasper.info",
  "address": { "street": "Norberto Crossing", "city": "South Christy", "geo": { "lat": "-71.4197", "lng": "71.7478" } },
  "company": { "name": "Considine-Lockman" }
}
```

After the converter:

```xml
<root>
  <id>6</id>
  <name>Mrs. Dennis Schulist</name>
  <username>Leopoldo_Corkery</username>
  <email>Karley_Dach@jasper.info</email>
  <address>
    <street>Norberto Crossing</street>
    <city>South Christy</city>
    <geo><lat>-71.4197</lat><lng>71.7478</lng></geo>
  </address>
  <company><name>Considine-Lockman</name></company>
</root>
```

## Learnings

- **Why the root element matters.** XML needs exactly one root, and a JSON
  object has none. With *Add XML Root Element* off, a single object
  with several top-level keys can't become well-formed XML. A top-level
  JSON **array** (for example `/users`) definitely needs the wrapper.
- **Arrays become repeated elements named after their key.**
  `"tags": ["a","b"]` becomes `<tags>a</tags><tags>b</tags>`. There is no
  wrapper element for the array itself, so a one-item array and a plain
  field produce identical XML.
- **Types are lost.** JSON `6` (number) and `"6"` (string) both become text
  `<id>6</id>`. Converting back with XML to JSON needs explicit settings
  to get numbers and arrays back. A single-item array in particular comes
  back as an object unless it's declared as an array.
- **Namespace mapping** only matters when JSON keys carry a prefix such as
  `"ns:field"`. Here it's on but unused.
