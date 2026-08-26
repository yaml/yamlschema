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
    <h1><span>Define a lot more</span><br><span>with a lot less</span></h1>
    <p class="home-lead">
      YAMLSchema mirrors the data you validate, keeps required fields obvious,
      and roundtrips with the JSON Schema ecosystem.
    </p>
    <div class="home-actions">
      <a class="ys-button ys-button-primary" href="demo/">
        Try the Demo
      </a>
      <a class="ys-button ys-button-secondary" href="getting-started/">
        Get Started
      </a>
      <a class="ys-button ys-button-secondary" href="cheat-sheet/">
        Cheat Sheet
      </a>
    </div>
  </div>
  <div class="home-proof" data-editor-href="demo/person/" role="link"
       tabindex="0" aria-label="Open Person in the demo">
    <span class="proof-label">A complete object schema</span>
    <pre><code>name: +Str
age?: +Int 0..120
email?: +JSONSchema/email
tags?: +Str[] [=good, bad, ugly]</code></pre>
  </div>
</section>

<section class="benefit-grid" aria-label="YAMLSchema benefits">
  <article>
    <h2>Shape mirrors data</h2>
    <p>Read the schema the same way you read the YAML it validates.</p>
  </article>
  <article>
    <h2>Required by default</h2>
    <p>Add one question mark when a field is optional. Nothing is hidden.</p>
  </article>
  <article>
    <h2>JSON Schema compatible</h2>
    <p>Convert, normalize, and inspect roundtrip differences in the browser.</p>
  </article>
</section>

## Install the CLI

=== "Bash and Zsh"

    ```bash
    source <(curl -sL yamlschema.org/install)
    ```

=== "Fish"

    ```fish
    curl -sL yamlschema.org/install | source -
    ```

Running the sourced command adds `ysd` to the current shell and immediately
enables tab completion and the YAMLSchema man pages.
The matching source release is kept under `$PREFIX/share/yamlschema/`.
[See installation options](getting-started.md#install-the-command).

## See the difference

The same constraints stay close to the fields they describe.
Choose an example, or click the comparison to continue in the editor.

<section class="comparison-carousel" data-comparison-carousel
         aria-label="YAMLSchema and JSON Schema comparisons">
  <div class="comparison-viewport">
    <article class="comparison-slide is-active" data-comparison-slide
             data-editor-href="demo/person/"
             tabindex="0" aria-label="Open Person in the editor">
      <div class="comparison-title">
        <div><h3>Person</h3></div>
        <a href="demo/person/">Open in editor</a>
      </div>
      <div class="comparison-panes">
        <div>
          <h4>YAMLSchema</h4>
          <pre><code>name: +Str
age?: +Int 0..120
email?: +JSONSchema/email
tags?: +Str[] [=good, bad, ugly]</code></pre>
        </div>
        <div>
          <h4>JSON Schema</h4>
          <pre><code>{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {
      "type": "string",
      "format": "email"
    },
    "age": {
      "type": "integer",
      "minimum": 0,
      "maximum": 120
    },
    "tags": {
      "type": "array",
      "default": "good",
      "items": {
        "type": "string",
        "enum": ["good", "bad", "ugly"]
      }
    }
  },
  "required": ["name"],
  "additionalProperties": false
}</code></pre>
        </div>
      </div>
    </article>
    <article class="comparison-slide" data-comparison-slide
             data-editor-href="demo/address/"
             tabindex="0" aria-label="Open Address in the editor">
      <div class="comparison-title">
        <div><h3>Address</h3></div>
        <a href="demo/address/">Open in editor</a>
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
             data-editor-href="demo/device-type/"
             tabindex="0" aria-label="Open Device Type in the editor">
      <div class="comparison-title">
        <div><h3>Device Type</h3></div>
        <a href="demo/device-type/">
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

### .ysd

The compact source form people write and review.

```yaml
name: +Str
age?: +Int 0..
```

</div>

<div markdown>

### .ysdc

The explicit canonical form for tools and generated artifacts.

```yaml
name: +Str
age?:
  .type: +Int
  .range: [0]
```

</div>

<div markdown>

### .ysdc JSON

The explicit canonical form encoded as JSON.

```json
{
  "name": "+Str",
  "age?": {
    ".type": "+Int",
    ".range": [0]
  }
}
```

</div>

</div>

<section class="home-closing">
  <p>Start with the shape of your data. Add only the constraints you need.</p>
  <a class="ys-button ys-button-primary" href="demo/">Try YAMLSchema</a>
</section>
