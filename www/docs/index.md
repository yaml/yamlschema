---
title: YAMLSchema
description: Define a lot more with a lot less
hide:
- navigation
- toc
---

<section class="home-hero">
  <div class="home-hero-copy">
    <p class="home-eyebrow">YAML-native data schemas</p>
    <h1>Define a lot more<br>with a lot less</h1>
    <p class="home-lead">
      YAMLSchema mirrors the data you validate, keeps required fields obvious,
      and roundtrips with the JSON Schema ecosystem.
    </p>
    <div class="home-actions">
      <a class="ys-button ys-button-primary" href="editor/">
        Try the Editor
      </a>
      <a class="ys-button ys-button-secondary" href="getting-started/">
        Get Started
      </a>
      <a class="ys-button ys-button-secondary" href="cheat-sheet/">
        Cheat Sheet
      </a>
    </div>
  </div>
  <div class="home-proof" aria-label="YAMLSchema example">
    <span class="proof-label">A complete object schema</span>
    <pre><code>name: +Str
email?: +JSONSchema/email
age?: +Int 0..
tags?: +Str[]</code></pre>
  </div>
</section>

<section class="benefit-grid" aria-label="YAMLSchema benefits">
  <article>
    <span>01</span>
    <h2>Shape mirrors data</h2>
    <p>Read the schema the same way you read the YAML it validates.</p>
  </article>
  <article>
    <span>02</span>
    <h2>Required by default</h2>
    <p>Add one question mark when a field is optional. Nothing is hidden.</p>
  </article>
  <article>
    <span>03</span>
    <h2>JSON Schema compatible</h2>
    <p>Convert, normalize, and inspect roundtrip differences in the browser.</p>
  </article>
</section>

## See the difference

The same constraints stay close to the fields they describe.
Choose an example, or click the comparison to continue in the editor.

<section class="comparison-carousel" data-comparison-carousel
         aria-label="YAMLSchema and JSON Schema comparisons">
  <div class="comparison-viewport">
    <article class="comparison-slide is-active" data-comparison-slide
             data-editor-href="editor/?source=ysd&amp;example=person"
             tabindex="0" aria-label="Open Person in the editor">
      <div class="comparison-title">
        <div><span>01</span><h3>Person</h3></div>
        <a href="editor/?source=ysd&amp;example=person">Open in editor</a>
      </div>
      <div class="comparison-panes">
        <div>
          <h4>YAMLSchema</h4>
          <pre><code>.title: Person
age?: +Int 0..
name: +Str</code></pre>
        </div>
        <div>
          <h4>JSON Schema</h4>
          <pre><code>{
  "title": "Person",
  "type": "object",
  "properties": {
    "age": {
      "type": "integer",
      "minimum": 0
    },
    "name": {"type": "string"}
  },
  "required": ["name"],
  "additionalProperties": false
}</code></pre>
        </div>
      </div>
    </article>
    <article class="comparison-slide" data-comparison-slide
             data-editor-href="editor/?source=json&amp;example=address"
             tabindex="0" aria-label="Open Address in the editor">
      <div class="comparison-title">
        <div><span>02</span><h3>Address</h3></div>
        <a href="editor/?source=json&amp;example=address">Open in editor</a>
      </div>
      <div class="comparison-panes">
        <div>
          <h4>YAMLSchema</h4>
          <pre><code>postOfficeBox?: +Str :need(streetAddress)
extendedAddress?: +Str :need(streetAddress)
streetAddress?: +Str
locality: +Str
region: +Str
postalCode?: +Str
countryName: +Str</code></pre>
        </div>
        <div>
          <h4>JSON Schema</h4>
          <pre><code>{
  "type": "object",
  "properties": {
    "postOfficeBox": {"type": "string"},
    "extendedAddress": {"type": "string"},
    "streetAddress": {"type": "string"}
  },
  "required": ["locality", "region", "countryName"],
  "dependentRequired": {
    "postOfficeBox": ["streetAddress"],
    "extendedAddress": ["streetAddress"]
  }
}</code></pre>
        </div>
      </div>
    </article>
    <article class="comparison-slide" data-comparison-slide
             data-editor-href="editor/?source=json&amp;example=device-type"
             tabindex="0" aria-label="Open Device Type in the editor">
      <div class="comparison-title">
        <div><span>03</span><h3>Device Type</h3></div>
        <a href="editor/?source=json&amp;example=device-type">
          Open in editor
        </a>
      </div>
      <div class="comparison-panes">
        <div>
          <h4>YAMLSchema</h4>
          <pre><code>deviceType: +Str
.one:
- .xref: https://example.com/smartphone.schema.json
  deviceType?: +Str ==smartphone
- .xref: https://example.com/laptop.schema.json
  deviceType?: +Str ==laptop</code></pre>
        </div>
        <div>
          <h4>JSON Schema</h4>
          <pre><code>{
  "type": "object",
  "required": ["deviceType"],
  "oneOf": [
    {
      "properties": {
        "deviceType": {"const": "smartphone"}
      },
      "$ref": "https://example.com/smartphone.schema.json"
    },
    {
      "properties": {
        "deviceType": {"const": "laptop"}
      },
      "$ref": "https://example.com/laptop.schema.json"
    }
  ]
}</code></pre>
        </div>
      </div>
    </article>
  </div>
  <div class="comparison-controls" aria-label="Choose a comparison">
    <button type="button" data-carousel-previous
            aria-label="Previous comparison">&larr;</button>
    <div class="comparison-dots">
      <button type="button" class="is-active" data-carousel-dot="0"
              aria-label="Show Person" aria-pressed="true"></button>
      <button type="button" data-carousel-dot="1"
              aria-label="Show Address" aria-pressed="false"></button>
      <button type="button" data-carousel-dot="2"
              aria-label="Show Device Type" aria-pressed="false"></button>
    </div>
    <button type="button" data-carousel-next
            aria-label="Next comparison">&rarr;</button>
  </div>
</section>

## One language, three useful forms

<div class="format-grid" markdown>

<div markdown>

### YSD

The compact source form people write and review.

```yaml
name: +Str
age?: +Int 0..
```

</div>

<div markdown>

### YSDC

The explicit canonical form for tools and generated artifacts.

```yaml
name: +Str
age?:
  .type: +Int
  .range: [0]
```

</div>

<div markdown>

### JSON Schema

The interchange form for the existing JSON Schema ecosystem.

```json
{"type": "object", "properties": {"name": {"type": "string"}}}
```

</div>

</div>

<section class="home-closing">
  <p>Start with the shape of your data. Add only the constraints you need.</p>
  <a class="ys-button ys-button-primary" href="editor/">Try YAMLSchema</a>
</section>
