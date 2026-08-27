importScripts('wasm_exec.js?v=3');
importScripts('unified-diff.js?v=2');

let ready = false;
let pending;

function checkRoundtrip({id, source, input, filename}) {
  try {
    const operation = {
      json: 'json-schema-roundtrip-report',
      ysd: 'ysd-roundtrip-report',
    }[source];
    if (!operation) throw new Error(`Unknown roundtrip source: ${source}`);
    const result = globalThis.gloat.exports[operation](input);
    if (!result.ok) throw new Error(result.error || 'Roundtrip check failed');
    const report = JSON.parse(result.value);
    const diff = report.works
      ? ''
      : globalThis.createUnifiedDiff(
        report.original,
        report.roundtripped,
        3,
        filename,
      );
    if (!report.works && !diff) {
      throw new Error('Roundtrip mismatch produced an empty diff');
    }
    postMessage({
      type: 'result',
      id,
      works: Boolean(report.works),
      diff,
      filename,
    });
  } catch (error) {
    postMessage({type: 'error', id, error: String(error)});
  }
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
WebAssembly.instantiateStreaming(fetch('ysd.wasm?v=18'), go.importObject)
  .then(({instance}) => go.run(instance))
  .catch((error) => {
    postMessage({type: 'error', error: String(error)});
  });
