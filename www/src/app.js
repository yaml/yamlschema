const jsonEditor = document.querySelector('#json-schema');
const yamlEditor = document.querySelector('#yaml-schema');
const jsonError = document.querySelector('#json-error');
const yamlError = document.querySelector('#yaml-error');
const status = document.querySelector('#status');

const sample = `{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Person",
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer", "minimum": 0}
  }
}`;

let timer;
let updating = false;

function showResult(source, target, errorElement, result) {
  if (result.ok) {
    source.classList.remove('invalid');
    errorElement.textContent = '';
    updating = true;
    target.value = result.value;
    updating = false;
  } else {
    source.classList.add('invalid');
    errorElement.textContent = result.error;
  }
}

function convertFrom(editor) {
  if (!globalThis.gloat || updating) return;
  if (editor === jsonEditor) {
    showResult(
      jsonEditor,
      yamlEditor,
      jsonError,
      globalThis.gloat.exports['json-schema-to-ysd'](jsonEditor.value),
    );
  } else {
    showResult(
      yamlEditor,
      jsonEditor,
      yamlError,
      globalThis.gloat.exports['ysd-to-json-schema'](yamlEditor.value),
    );
  }
}

function schedule(editor) {
  clearTimeout(timer);
  timer = setTimeout(() => convertFrom(editor), 250);
}

jsonEditor.addEventListener('input', () => schedule(jsonEditor));
yamlEditor.addEventListener('input', () => schedule(yamlEditor));

globalThis.addEventListener('gloat-ready', () => {
  status.textContent = 'Ready';
  jsonEditor.value = sample;
  convertFrom(jsonEditor);
});

const go = new Go();
WebAssembly.instantiateStreaming(fetch('ysc.wasm'), go.importObject)
  .then(({instance}) => go.run(instance))
  .catch((error) => {
    status.textContent = `Load error: ${error}`;
  });
