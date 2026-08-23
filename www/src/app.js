import {normalizeJson} from './json.js?v=3';

const jsonEditor = document.querySelector('#json-schema');
const yamlEditor = document.querySelector('#yaml-schema');
const jsonError = document.querySelector('#json-error');
const yamlError = document.querySelector('#yaml-error');
const sampleSelect = document.querySelector('#sample-select');
const normalizeJsonButton = document.querySelector('#normalize-json');
const roundtripStatuses = document.querySelectorAll('.roundtrip-status');
const roundtripDiffDialog = document.querySelector(
  '#roundtrip-diff-dialog',
);
const roundtripDiffOutput = document.querySelector('#roundtrip-diff');
const roundtripDiffClose = document.querySelector('#roundtrip-diff-close');
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
  'harbor-next': {format: 'ysd', url: 'values.ysd.yaml?v=2'},
  address: {format: 'json', url: 'examples/address.schema.json?v=1'},
  'blog-post': {
    format: 'json',
    url: 'examples/blog-post.schema.json?v=1',
  },
  calendar: {format: 'json', url: 'examples/calendar.schema.json?v=2'},
  'device-type': {
    format: 'json',
    url: 'examples/device-type.schema.json?v=2',
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
  movie: {format: 'json', url: 'examples/movie.schema.json?v=2'},
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
let roundtripSource;
let conversionRequest = 0;
let workerRequest = 0;
let schemaWorkerReady = false;
let updating = false;
let yamlFormat = loadYamlFormat();
let ysdValue = '';
let roundtripDiff = '';
const workerCalls = new Map();
const schemaWorker = new Worker('schema-worker.js?v=13');

function loadYamlFormat() {
  try {
    return localStorage.getItem(formatStorageKey) === 'ysdc' ? 'ysdc' : 'ysd';
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

function showGeneratingYSDC() {
  if (yamlFormat === 'ysdc') {
    setEditorValue(yamlEditor, 'Generating YSDC...');
  }
}

function showGeneratingYamlSchema() {
  const name = yamlFormat === 'ysdc' ? 'YSDC' : 'YSD';
  setEditorValue(yamlEditor, `Generating ${name}...`);
}

function showGeneratingJSONSchema() {
  setEditorValue(jsonEditor, 'Generating JSON Schema...');
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
    const active = indicator.dataset.roundtripSource === roundtripSource;
    indicator.textContent = symbol;
    indicator.className = `roundtrip-status ${status}` +
      (active ? ' source-active' : '');
    indicator.title = title;
    indicator.setAttribute('aria-label', title);
    indicator.setAttribute('aria-hidden', String(!active));
    indicator.disabled = !active || status !== 'fails' || !roundtripDiff;
  }
}

function setRoundtripSource(source) {
  roundtripSource = source;
  for (const indicator of roundtripStatuses) {
    const active = indicator.dataset.roundtripSource === source;
    indicator.classList.toggle('source-active', active);
    indicator.setAttribute('aria-hidden', String(!active));
    indicator.disabled = !active ||
      !indicator.classList.contains('fails') ||
      !roundtripDiff;
  }
}

function setRoundtripDiff(diff) {
  roundtripDiff = diff;
  if (diff) return;
  for (const indicator of roundtripStatuses) indicator.disabled = true;
  roundtripDiffOutput.replaceChildren();
  if (roundtripDiffDialog.open) roundtripDiffDialog.close();
}

function diffLineClass(line, index) {
  if (index < 2) return 'diff-file-header';
  if (line.startsWith('@@')) return 'diff-hunk-header';
  if (line.startsWith('+')) return 'diff-addition';
  if (line.startsWith('-')) return 'diff-deletion';
  return 'diff-context';
}

function showRoundtripDiff() {
  if (!roundtripDiff) return;
  const fragment = document.createDocumentFragment();
  const lines = roundtripDiff.replace(/\n$/, '').split('\n');
  for (const [index, line] of lines.entries()) {
    const row = document.createElement('span');
    row.className = diffLineClass(line, index);
    row.textContent = `${line}\n`;
    fragment.append(row);
  }
  roundtripDiffOutput.replaceChildren(fragment);
  roundtripDiffDialog.showModal();
  roundtripDiffOutput.focus();
}

function failWorker(error) {
  const message = `Worker error: ${error}`;
  schemaWorkerReady = false;
  normalizeJsonButton.disabled = true;
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
  roundtripWorker = new Worker('roundtrip-worker.js?v=14');
  roundtripWorker.addEventListener('message', ({data}) => {
    if (data.id !== undefined && data.id !== roundtripRequest) return;
    roundtripBusy = false;
    if (data.type === 'error') {
      setRoundtripDiff('');
      setRoundtripStatus('unknown', 'Roundtrip Check Error');
    } else {
      setRoundtripDiff(data.diff || '');
      setRoundtripStatus(data.works ? 'works' : 'fails');
    }
  });
  roundtripWorker.addEventListener('error', () => {
    roundtripBusy = false;
    setRoundtripDiff('');
    setRoundtripStatus('unknown', 'Roundtrip Check Error');
  });
  return roundtripWorker;
}

function updateRoundtripStatus(source, input, delay = 500) {
  clearTimeout(roundtripTimer);
  setRoundtripSource(source);
  const id = ++roundtripRequest;
  roundtripTimer = setTimeout(() => {
    roundtripBusy = true;
    getRoundtripWorker().postMessage({id, source, input});
  }, delay);
}

function cancelRoundtripStatus() {
  clearTimeout(roundtripTimer);
  roundtripRequest++;
  setRoundtripDiff('');
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

async function convertJsonToYaml(
  updateYSD = true,
  checkRoundtrip = true,
) {
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
  showGeneratingYamlSchema();
  if (checkRoundtrip) updateRoundtripStatus('json', json);
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
  if (yamlFormat === 'ysdc') {
    result = await callWorker('json-schema-to-ysdc', json);
    if (id !== conversionRequest) return;
  }
  showResult(jsonEditor, yamlEditor, jsonError, yamlError, result);
}

async function convertYamlToJson() {
  const id = ++conversionRequest;
  const ysd = yamlEditor.value;
  ysdValue = ysd;
  showGeneratingJSONSchema();
  const result = await callWorker('ysd-to-json-schema', ysd);
  if (id !== conversionRequest) return;
  showResult(yamlEditor, jsonEditor, yamlError, jsonError, result);
  if (result.ok) {
    updateRoundtripStatus('ysd', ysd);
  } else {
    cancelRoundtripStatus();
    setRoundtripStatus('unknown', 'YAML Schema Error');
  }
  return result;
}

async function normalizeJsonSchema() {
  if (!schemaWorkerReady || updating) return;
  normalizeJsonButton.disabled = true;
  const id = ++conversionRequest;
  clearTimeout(timer);
  clearTimeout(checkingTimer);
  setRoundtripSource('json');
  cancelRoundtripStatus();
  setRoundtripStatus('checking');
  try {
    let json;
    try {
      json = normalizeJson(jsonEditor.value);
    } catch (error) {
      jsonEditor.classList.add('invalid');
      jsonError.textContent = error.message;
      setRoundtripStatus('unknown');
      return;
    }
    const result = await callWorker('json-schema-normalize', json);
    if (id !== conversionRequest) return;
    if (!result.ok) {
      jsonEditor.classList.add('invalid');
      jsonError.textContent = result.error;
      setRoundtripStatus('unknown', 'JSON Schema Normalize Error');
      return;
    }
    setEditorValue(jsonEditor, result.value);
    await convertJsonToYaml();
  } finally {
    normalizeJsonButton.disabled = !schemaWorkerReady;
  }
}

function convertFrom(editor) {
  if (!schemaWorkerReady || updating) return;
  if (editor === jsonEditor) void convertJsonToYaml();
  else if (yamlFormat === 'ysd') void convertYamlToJson();
}

function roundtripOnFocus(editor) {
  if (!schemaWorkerReady || updating) return;
  if (editor === yamlEditor && yamlFormat !== 'ysd') return;
  const source = editor === jsonEditor ? 'json' : 'ysd';
  cancelRoundtripStatus();
  clearTimeout(checkingTimer);
  setRoundtripSource(source);
  setRoundtripStatus('checking');
  if (editor === yamlEditor) {
    updateRoundtripStatus('ysd', yamlEditor.value, 0);
    return;
  }
  try {
    const json = normalizeJson(jsonEditor.value);
    updateRoundtripStatus('json', json, 0);
  } catch {
    setRoundtripStatus('unknown');
  }
}

function closeDiffFromBackdrop(event) {
  if (event.target !== roundtripDiffDialog) return;
  const bounds = roundtripDiffDialog.getBoundingClientRect();
  const outside = event.clientX < bounds.left ||
    event.clientX > bounds.right ||
    event.clientY < bounds.top ||
    event.clientY > bounds.bottom;
  if (outside) roundtripDiffDialog.close();
}

async function showSample(ysd) {
  ysdValue = ysd;
  setEditorValue(yamlEditor, ysdValue);
  const conversion = convertYamlToJson();
  showGeneratingYSDC();
  const result = await conversion;
  if (yamlFormat === 'ysdc' && result?.ok) {
    await convertJsonToYaml(false, false);
  }
}

async function showJsonSample(json) {
  setEditorValue(jsonEditor, json);
  await convertJsonToYaml();
}

async function loadSelectedSample() {
  sampleSelect.disabled = true;
  normalizeJsonButton.disabled = true;
  const sample = sampleSources[sampleSelect.value] || sampleSources.person;
  setRoundtripSource(sample.format);
  setRoundtripStatus('checking');
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
    normalizeJsonButton.disabled = !schemaWorkerReady;
  }
}

function selectYamlFormat(format, remember = true) {
  yamlFormat = format;
  if (remember) saveYamlFormat(format);
  const readonly = format === 'ysdc';
  yamlEditor.toggleAttribute('readonly', readonly);
  yamlEditor.classList.toggle('readonly', readonly);
  yamlEditor.classList.remove('invalid');
  yamlError.textContent = '';
  if (!schemaWorkerReady) return;
  if (format === 'ysd' && ysdValue) setEditorValue(yamlEditor, ysdValue);
  else {
    showGeneratingYSDC();
    void convertJsonToYaml(false, false);
  }
}

function schedule(editor) {
  const source = editor === jsonEditor ? 'json' : 'ysd';
  setRoundtripSource(source);
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
jsonEditor.addEventListener('focus', () => roundtripOnFocus(jsonEditor));
yamlEditor.addEventListener('focus', () => roundtripOnFocus(yamlEditor));
for (const indicator of roundtripStatuses) {
  indicator.addEventListener('click', showRoundtripDiff);
}
roundtripDiffDialog.addEventListener('click', closeDiffFromBackdrop);
roundtripDiffClose.addEventListener('click', () => {
  roundtripDiffDialog.close();
});
normalizeJsonButton.addEventListener('click', () => {
  void normalizeJsonSchema();
});
sampleSelect.value = loadSample();
sampleSelect.addEventListener('change', () => {
  saveSample(sampleSelect.value);
  cancelRoundtripStatus();
  clearTimeout(checkingTimer);
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
    normalizeJsonButton.disabled = false;
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
