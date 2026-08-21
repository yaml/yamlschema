importScripts('wasm_exec.js?v=3');

let ready = false;
let pending;

function checkRoundtrip({id, json}) {
  const result = globalThis.gloat.exports[
    'json-schema-roundtrip-works'
  ](json);
  postMessage({
    type: 'result',
    id,
    works: result.ok && result.value,
  });
}

globalThis.addEventListener('message', ({data}) => {
  if (ready) checkRoundtrip(data);
  else pending = data;
});

globalThis.addEventListener('gloat-ready', () => {
  ready = true;
  if (pending) {
    checkRoundtrip(pending);
    pending = undefined;
  }
});

const go = new Go();
WebAssembly.instantiateStreaming(fetch('ysc.wasm?v=4'), go.importObject)
  .then(({instance}) => go.run(instance))
  .catch((error) => {
    postMessage({type: 'error', error: String(error)});
  });
