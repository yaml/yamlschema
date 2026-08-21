import '../site/wasm_exec.js';
import {readFile} from 'node:fs/promises';
import {normalizeJson} from '../src/json.js';

const trailing = normalizeJson('{"a": [1, 2,],}');
if (JSON.stringify(JSON.parse(trailing)) !== '{"a":[1,2]}') {
  throw new Error('trailing JSON commas were not normalized');
}

if (normalizeJson('{"text": ",}"}') !== '{"text": ",}"}') {
  throw new Error('a comma inside a JSON string was changed');
}

for (const invalidJSON of [
  '{"title": not valid json}',
  '{"a": 1 "b": 2}',
]) {
  try {
    normalizeJson(invalidJSON);
    throw new Error(`invalid JSON was accepted: ${invalidJSON}`);
  } catch (error) {
    if (error.message.startsWith('invalid JSON was accepted')) throw error;
  }
}

const go = new Go();
const bytes = await readFile('ysc.wasm');
const {instance} = await WebAssembly.instantiate(bytes, go.importObject);
go.run(instance);

for (let attempt = 0; attempt < 200 && !globalThis.gloat; attempt += 1) {
  await new Promise((resolve) => setTimeout(resolve, 10));
}

if (!globalThis.gloat) throw new Error('gloat export object was not installed');

const appSource = await readFile('../src/app.js', 'utf8');
if (appSource.includes('globalThis.gloat')) {
  throw new Error('the browser app calls Wasm on the UI thread');
}
for (const worker of ['schema-worker.js', 'roundtrip-worker.js']) {
  if (!appSource.includes(`new Worker('${worker}`)) {
    throw new Error(`${worker} is not used by the browser app`);
  }
}
if (!appSource.includes('roundtripWorker.terminate()')) {
  throw new Error('stale roundtrip work is not cancelled');
}

const pastedYSD = await readFile('../test/ansible-builder.ysd.yaml', 'utf8');
const pastedResult = globalThis.gloat.exports['ysd-to-json-schema'](
  pastedYSD,
);
if (!pastedResult.ok) {
  throw new Error(`pasted YSD conversion failed: ${JSON.stringify(
    pastedResult,
  )}`);
}
const pastedRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](pastedResult.value);
if (!pastedRoundtrip.ok || pastedRoundtrip.value !== true) {
  throw new Error(`pasted YSD did not roundtrip: ${JSON.stringify(
    pastedRoundtrip,
  )}`);
}

const exampleFiles = [
  'address',
  'blog-post',
  'calendar',
  'device-type',
  'ecommerce-system',
  'geographical-location',
  'health-record',
  'job-posting',
  'movie',
  'user-profile',
];
const indexHTML = await readFile('index.html', 'utf8');
for (const name of exampleFiles) {
  if (!indexHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is missing from the sample selector`);
  }
  const text = await readFile(`examples/${name}.schema.json`, 'utf8');
  const schema = JSON.parse(text);
  if (schema.$schema !== 'https://json-schema.org/draft/2020-12/schema') {
    throw new Error(`${name} does not use JSON Schema 2020-12`);
  }
  const converted = globalThis.gloat.exports['json-schema-to-ysd'](text);
  if (!converted.ok) {
    throw new Error(`${name} conversion failed: ${JSON.stringify(
      converted,
    )}`);
  }
  const roundtrip = globalThis.gloat.exports[
    'json-schema-roundtrip-works'
  ](text);
  if (!roundtrip.ok || typeof roundtrip.value !== 'boolean') {
    throw new Error(`${name} roundtrip check failed: ${JSON.stringify(
      roundtrip,
    )}`);
  }
}

const initialYSD = `.title: Person
age?: +Int 0..
name: +Str`;
const initialResult = globalThis.gloat.exports['ysd-to-json-schema'](
  initialYSD,
);
if (!initialResult.ok) {
  throw new Error(`initial YSD conversion failed: ${JSON.stringify(
    initialResult,
  )}`);
}
const initialJSON = JSON.parse(initialResult.value);
if (
  initialJSON.$schema !==
    'https://json-schema.org/draft/2020-12/schema' ||
  initialJSON.title !== 'Person' ||
  initialJSON.type !== 'object' ||
  initialJSON.additionalProperties !== false ||
  initialJSON.required.join(',') !== 'name' ||
  Object.keys(initialJSON.properties).join(',') !== 'age,name' ||
  initialJSON.properties.age.type !== 'integer' ||
  initialJSON.properties.age.minimum !== 0 ||
  initialJSON.properties.name.type !== 'string'
) {
  throw new Error(`unexpected initial JSON: ${initialResult.value}`);
}
const initialRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](initialResult.value);
if (!initialRoundtrip.ok || initialRoundtrip.value !== true) {
  throw new Error(`initial schema did not roundtrip: ${JSON.stringify(
    initialRoundtrip,
  )}`);
}

const harborYSD = await readFile('values.ysd.yaml', 'utf8');
const harborResult = globalThis.gloat.exports['ysd-to-json-schema'](
  harborYSD,
);
if (!harborResult.ok) {
  throw new Error(`Harbor Next sample failed: ${JSON.stringify(
    harborResult,
  )}`);
}
const harborJSON = JSON.parse(harborResult.value);
if (harborJSON.title !== 'Harbor Next Helm Chart Values') {
  throw new Error(`unexpected Harbor Next title: ${harborJSON.title}`);
}
const harborKeys = Object.keys(harborJSON).slice(0, 6).join(',');
const expectedHarborKeys = '$id,$schema,title,description,type,properties';
if (harborKeys !== expectedHarborKeys) {
  throw new Error(`unexpected Harbor Next key order: ${harborKeys}`);
}
const harborRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](harborResult.value);
if (!harborRoundtrip.ok || harborRoundtrip.value !== true) {
  throw new Error(`Harbor Next sample did not roundtrip: ${JSON.stringify(
    harborRoundtrip,
  )}`);
}

const json = JSON.stringify({
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  required: ['name'],
  properties: {name: {type: 'string'}},
});
const toYSD = globalThis.gloat.exports['json-schema-to-ysd'](json);
if (!toYSD.ok || !toYSD.value.includes('name:')) {
  throw new Error(`JSON to YSD failed: ${JSON.stringify(toYSD)}`);
}

const toJSON = globalThis.gloat.exports['ysd-to-json-schema'](toYSD.value);
if (!toJSON.ok || JSON.parse(toJSON.value).type !== 'object') {
  throw new Error(`YSD to JSON failed: ${JSON.stringify(toJSON)}`);
}

const toYSC = globalThis.gloat.exports['json-schema-to-ysc'](json);
const expectedYSC = '.open: true\nname: +Str';
if (!toYSC.ok || toYSC.value !== expectedYSC) {
  throw new Error(`JSON to YSC failed: ${JSON.stringify(toYSC)}`);
}

const failedRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](json);
if (!failedRoundtrip.ok || failedRoundtrip.value !== false) {
  throw new Error(`expected roundtrip failure: ${JSON.stringify(
    failedRoundtrip,
  )}`);
}

const closed = JSON.stringify({
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  properties: {name: {type: 'string'}},
  additionalProperties: false,
});
const workingRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](closed);
if (!workingRoundtrip.ok || workingRoundtrip.value !== true) {
  throw new Error(`expected working roundtrip: ${JSON.stringify(
    workingRoundtrip,
  )}`);
}

const invalid = globalThis.gloat.exports['json-schema-to-ysd']('{');
if (invalid.ok || !invalid.error) {
  throw new Error('invalid JSON did not return an error envelope');
}

for (const invalidYSD of ['bad: [', '.unknown: true', 'name: +Stx']) {
  const result = globalThis.gloat.exports['ysd-to-json-schema'](invalidYSD);
  if (result.ok || !result.error) {
    throw new Error(`invalid YSD did not return an error: ${invalidYSD}`);
  }
}

console.log('browser exports converted YSD, YSC, and JSON');
process.exit(0);
