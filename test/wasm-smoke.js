'use strict';

const fs = require('fs');

async function main() {
  const [wasmExec, wasmFile, inputFile] = process.argv.slice(2);
  if (!wasmExec || !wasmFile || !inputFile) {
    throw new Error('usage: wasm-smoke.js WASM-EXEC WASM INPUT');
  }

  require(wasmExec);
  const go = new Go();
  const bytes = fs.readFileSync(wasmFile);
  const {instance} = await WebAssembly.instantiate(bytes, go.importObject);
  void go.run(instance);

  while (!globalThis.gloat) {
    await new Promise((resolve) => setTimeout(resolve, 1));
  }

  const input = fs.readFileSync(inputFile, 'utf8');
  const result = globalThis.gloat.exports['json-schema-to-ysd'](input);
  if (!result.ok) throw new Error(result.error);
  process.stdout.write(`${result.value}\n`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
