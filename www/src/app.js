import {normalizeJson} from './json.js?v=3';

const jsonEditor = document.querySelector('#json-schema');
const yamlEditor = document.querySelector('#yaml-schema');
const jsonError = document.querySelector('#json-error');
const yamlError = document.querySelector('#yaml-error');
const sampleSelect = document.querySelector('#sample-select');
const roundtripStatuses = document.querySelectorAll('.roundtrip-status');
const formatControls = document.querySelectorAll(
  'input[name="yaml-format"]',
);
const formatStorageKey = 'yamlschema.yaml-format';
const sampleStorageKey = 'yamlschema.sample';

const personYSD = `.title: Person
age?: +Int 0..
name: +Str`;
const sampleSources = {
  person: {format: 'ysd', text: personYSD},
  'harbor-next': {format: 'ysd', url: 'values.ysd.yaml?v=1'},
  address: {format: 'json', url: 'examples/address.schema.json?v=1'},
  'blog-post': {
    format: 'json',
    url: 'examples/blog-post.schema.json?v=1',
  },
  calendar: {format: 'json', url: 'examples/calendar.schema.json?v=1'},
  'device-type': {
    format: 'json',
    url: 'examples/device-type.schema.json?v=1',
  },
  'ecommerce-system': {
    format: 'json',
    url: 'examples/ecommerce-system.schema.json?v=1',
  },
  'geographical-location': {
    format: 'json',
    url: 'examples/geographical-location.schema.json?v=1',
  },
  'health-record': {
    format: 'json',
    url: 'examples/health-record.schema.json?v=1',
  },
  'job-posting': {
    format: 'json',
    url: 'examples/job-posting.schema.json?v=1',
  },
  movie: {format: 'json', url: 'examples/movie.schema.json?v=1'},
  'user-profile': {
    format: 'json',
    url: 'examples/user-profile.schema.json?v=1',
  },
};

let timer;
let checkingTimer;
let roundtripTimer;
let roundtripWorker;
let roundtripBusy = false;
let roundtripRequest = 0;
let conversionRequest = 0;
let workerRequest = 0;
let schemaWorkerReady = false;
let updating = false;
let yamlFormat = loadYamlFormat();
let ysdValue = '';
const workerCalls = new Map();
const schemaWorker = new Worker('schema-worker.js?v=2');

function loadYamlFormat() {
  try {
    return localStorage.getItem(formatStorageKey) === 'ysc' ? 'ysc' : 'ysd';
  } catch {
    return 'ysd';
  }
}

function saveYamlFormat(format) {
  try {
    localStorage.setItem(formatStorageKey, format);
  } catch {
    // The selector still works when storage is unavailable.
  }
}

function loadSample() {
  try {
    const sample = localStorage.getItem(sampleStorageKey);
    return Object.hasOwn(sampleSources, sample) ? sample : 'person';
  } catch {
    return 'person';
  }
}

function saveSample(sample) {
  try {
    localStorage.setItem(sampleStorageKey, sample);
  } catch {
    // The selector still works when storage is unavailable.
  }
}

function setEditorValue(editor, value) {
  updating = true;
  editor.value = value;
  updating = false;
}

function setRoundtripStatus(status, alternateTitle) {
  if (status !== 'checking') clearTimeout(checkingTimer);
  const states = {
    works: ['√', 'Roundtrip Works'],
    fails: ['X', 'Roundtrip Fails'],
    checking: ['…', 'Checking Roundtrip'],
    unknown: ['?', 'JSON Parse Error'],
  };
  const [symbol, defaultTitle] = states[status];
  const title = alternateTitle || defaultTitle;
  for (const indicator of roundtripStatuses) {
    indicator.textContent = symbol;
    indicator.className = `roundtrip-status ${status}`;
    indicator.title = title;
    indicator.setAttribute('aria-label', title);
  }
}

function failWorker(error) {
  const message = `Worker error: ${error}`;
  schemaWorkerReady = false;
  for (const resolve of workerCalls.values()) {
    resolve({ok: false, error: message});
  }
  workerCalls.clear();
  cancelRoundtripStatus();
  setRoundtripStatus('unknown', 'Conversion Worker Error');
  jsonEditor.classList.add('invalid');
  jsonError.textContent = message;
}

function callWorker(operation, input) {
  return new Promise((resolve) => {
    const id = ++workerRequest;
    workerCalls.set(id, resolve);
    schemaWorker.postMessage({type: 'call', id, operation, input});
  });
}

function getRoundtripWorker() {
  if (roundtripWorker) return roundtripWorker;
  roundtripWorker = new Worker('roundtrip-worker.js?v=2');
  roundtripWorker.addEventListener('message', ({data}) => {
    roundtripBusy = false;
    if (data.type === 'error') {
      setRoundtripStatus('unknown', 'Roundtrip Check Error');
    } else if (data.id === roundtripRequest) {
      setRoundtripStatus(data.works ? 'works' : 'fails');
    }
  });
  roundtripWorker.addEventListener('error', () => {
    roundtripBusy = false;
    setRoundtripStatus('unknown', 'Roundtrip Check Error');
  });
  return roundtripWorker;
}

function updateRoundtripStatus(json) {
  clearTimeout(roundtripTimer);
  const id = ++roundtripRequest;
  roundtripTimer = setTimeout(() => {
    roundtripBusy = true;
    getRoundtripWorker().postMessage({id, json});
  }, 500);
}

function cancelRoundtripStatus() {
  clearTimeout(roundtripTimer);
  roundtripRequest++;
  if (roundtripWorker && roundtripBusy) {
    roundtripWorker.terminate();
    roundtripWorker = undefined;
    roundtripBusy = false;
  }
}

function showResult(source, target, sourceError, targetError, result) {
  if (result.ok) {
    source.classList.remove('invalid');
    target.classList.remove('invalid');
    sourceError.textContent = '';
    targetError.textContent = '';
    setEditorValue(target, result.value);
  } else {
    source.classList.add('invalid');
    sourceError.textContent = result.error;
  }
}

async function convertJsonToYaml(updateYSD = true) {
  let json;
  try {
    json = normalizeJson(jsonEditor.value);
  } catch (error) {
    cancelRoundtripStatus();
    setRoundtripStatus('unknown');
    showResult(jsonEditor, yamlEditor, jsonError, yamlError, {
      ok: false,
      error: error.message,
    });
    return;
  }
  const id = ++conversionRequest;
  updateRoundtripStatus(json);
  const toYSD = await callWorker('json-schema-to-ysd', json);
  if (id !== conversionRequest) return;
  if (!toYSD.ok) {
    showResult(jsonEditor, yamlEditor, jsonError, yamlError, toYSD);
    return;
  }
  const convertedYSD = toYSD.value.replace(
    /^# Converted from JSON Schema\r?\n/,
    '',
  );
  if (updateYSD) ysdValue = convertedYSD;
  let result = {...toYSD, value: convertedYSD};
  if (yamlFormat === 'ysc') {
    result = await callWorker('json-schema-to-ysc', json);
    if (id !== conversionRequest) return;
  }
  showResult(jsonEditor, yamlEditor, jsonError, yamlError, result);
}

async function convertYamlToJson() {
  const id = ++conversionRequest;
  ysdValue = yamlEditor.value;
  const result = await callWorker('ysd-to-json-schema', yamlEditor.value);
  if (id !== conversionRequest) return;
  showResult(yamlEditor, jsonEditor, yamlError, jsonError, result);
  if (result.ok) {
    updateRoundtripStatus(result.value);
  } else {
    cancelRoundtripStatus();
    setRoundtripStatus('unknown', 'YAML Schema Error');
  }
  return result;
}

function convertFrom(editor) {
  if (!schemaWorkerReady || updating) return;
  if (editor === jsonEditor) void convertJsonToYaml();
  else if (yamlFormat === 'ysd') void convertYamlToJson();
}

async function showSample(ysd) {
  ysdValue = ysd;
  setEditorValue(yamlEditor, ysdValue);
  const result = await convertYamlToJson();
  if (yamlFormat === 'ysc' && result?.ok) {
    await convertJsonToYaml(false);
  }
}

async function showJsonSample(json) {
  setEditorValue(jsonEditor, json);
  await convertJsonToYaml();
}

async function loadSelectedSample() {
  sampleSelect.disabled = true;
  const sample = sampleSources[sampleSelect.value] || sampleSources.person;
  try {
    let source = sample.text;
    if (!source) {
      const response = await fetch(sample.url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      source = await response.text();
    }
    if (sample.format === 'json') await showJsonSample(source);
    else await showSample(source);
  } catch (error) {
    cancelRoundtripStatus();
    setRoundtripStatus('unknown', 'Sample Load Error');
    const editor = sample.format === 'json' ? jsonEditor : yamlEditor;
    const errorElement = sample.format === 'json' ? jsonError : yamlError;
    editor.classList.add('invalid');
    errorElement.textContent = `Sample load error: ${error.message}`;
  } finally {
    sampleSelect.disabled = false;
  }
}

function selectYamlFormat(format, remember = true) {
  yamlFormat = format;
  if (remember) saveYamlFormat(format);
  const readonly = format === 'ysc';
  yamlEditor.toggleAttribute('readonly', readonly);
  yamlEditor.classList.toggle('readonly', readonly);
  yamlEditor.classList.remove('invalid');
  yamlError.textContent = '';
  if (!schemaWorkerReady) return;
  if (format === 'ysd' && ysdValue) setEditorValue(yamlEditor, ysdValue);
  else void convertJsonToYaml(false);
}

function schedule(editor) {
  conversionRequest++;
  cancelRoundtripStatus();
  clearTimeout(timer);
  clearTimeout(checkingTimer);
  checkingTimer = setTimeout(() => {
    setRoundtripStatus('checking');
  }, 200);
  timer = setTimeout(() => convertFrom(editor), 250);
}

jsonEditor.addEventListener('input', () => schedule(jsonEditor));
yamlEditor.addEventListener('input', () => schedule(yamlEditor));
sampleSelect.value = loadSample();
sampleSelect.addEventListener('change', () => {
  saveSample(sampleSelect.value);
  cancelRoundtripStatus();
  clearTimeout(checkingTimer);
  setRoundtripStatus('checking');
  void loadSelectedSample();
});
for (const control of formatControls) {
  control.checked = control.value === yamlFormat;
  control.addEventListener('change', () => {
    if (control.checked) selectYamlFormat(control.value);
  });
}
selectYamlFormat(yamlFormat, false);

schemaWorker.addEventListener('message', ({data}) => {
  if (data.type === 'ready') {
    schemaWorkerReady = true;
    void loadSelectedSample();
    return;
  }
  if (data.type === 'error') {
    failWorker(data.error);
    return;
  }
  const resolve = workerCalls.get(data.id);
  if (!resolve) return;
  workerCalls.delete(data.id);
  resolve(data.result);
});
schemaWorker.addEventListener('error', (event) => {
  failWorker(event.message);
});
