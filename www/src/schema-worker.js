importScripts('wasm_exec.js?v=3');

let ready = false;
const pending = [];
const operations = new Set([
  'json-schema-normalize',
  'json-schema-to-ysc',
  'json-schema-to-ysd',
  'ysd-to-json-schema',
]);

function callExport({id, operation, input}) {
  try {
    if (!operations.has(operation)) {
      throw new Error(`Unknown operation: ${operation}`);
    }
    const fn = globalThis.gloat.exports[operation];
    const result = fn(input);
    postMessage({
      type: 'result',
      id,
      result: {
        ok: Boolean(result.ok),
        value: result.value,
        error: result.error,
      },
    });
  } catch (error) {
    postMessage({
      type: 'result',
      id,
      result: {ok: false, error: String(error)},
    });
  }
}

globalThis.addEventListener('message', ({data}) => {
  if (data.type !== 'call') return;
  if (ready) callExport(data);
  else pending.push(data);
});

globalThis.addEventListener('gloat-ready', () => {
  ready = true;
  postMessage({type: 'ready'});
  for (const request of pending.splice(0)) callExport(request);
});

const go = new Go();
WebAssembly.instantiateStreaming(fetch('ysc.wasm?v=13'), go.importObject)
  .then(({instance}) => go.run(instance))
  .catch((error) => {
    postMessage({type: 'error', error: String(error)});
  });
