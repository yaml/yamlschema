import '../site/wasm_exec.js';
import {readFile} from 'node:fs/promises';

const go = new Go();
const bytes = await readFile('ysc.wasm');
const {instance} = await WebAssembly.instantiate(bytes, go.importObject);
go.run(instance);

for (let attempt = 0; attempt < 200 && !globalThis.gloat; attempt += 1) {
  await new Promise((resolve) => setTimeout(resolve, 10));
}

if (!globalThis.gloat) throw new Error('gloat export object was not installed');

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

const invalid = globalThis.gloat.exports['json-schema-to-ysd']('{');
if (invalid.ok || !invalid.error) {
  throw new Error('invalid JSON did not return an error envelope');
}

console.log('browser exports converted both directions');
process.exit(0);
