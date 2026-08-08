#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: contact
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "$defs": {
        "phone": {
          "type": "string",
          "pattern": "^\\+?[0-9\\s\\-()]{7,20}$"
        }
      },
      "type": "object",
      "properties": {
        "name":   {"type": "string"},
        "email":  {"type": "string", "pattern": "^\\S+@\\S+$"},
        "phone":  {"$ref": "#/$defs/phone"},
        "phone2": {"$ref": "#/$defs/phone"},
        "address": {
          "type": "object",
          "properties": {
            "street":  {"type": "string"},
            "city":    {"type": "string"},
            "state":   {"type": "string", "pattern": "^[A-Z]{2}$"},
            "zip":     {"type": "string", "pattern": "^\\d{5}(-\\d{4})?$"},
            "country": {"type": "string"}
          },
          "required": ["street", "city", "state", "zip"]
        }
      },
      "required": ["name", "phone", "address"]
    }
  want: |
    +phone: +Str =~"\+?[0-9\s\-()]{7,20}"

    name: +Str
    email?: +Str =~"\S+@\S+"
    phone: +phone
    phone2?: +phone
    address:
      street: +Str
      city: +Str
      state: +Str =~"[A-Z]{2}"
      zip: +Str =~"\d{5}(-\d{4})?"
      country?: +Str

done:
