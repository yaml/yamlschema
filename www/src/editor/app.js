import {json} from '@codemirror/lang-json';
import {yaml} from '@codemirror/lang-yaml';

import {normalizeJson} from '../../docs/assets/editor/json.js';
import {CodeEditor} from './editor.js';
import {parseEditorState, serializeEditorState} from './url-state.js';

const schemaEditor = document.querySelector('.schema-editor');
const jsonEditorMount = document.querySelector('#json-schema');
const yamlEditorMount = document.querySelector('#yaml-schema');
const jsonError = document.querySelector('#json-error');
const yamlError = document.querySelector('#yaml-error');
const yamlSampleSelect = document.querySelector('#yaml-sample-select');
const jsonSampleSelect = document.querySelector('#json-sample-select');
const normalizeJsonButton = document.querySelector('#normalize-json');
const roundtripStatuses = document.querySelectorAll('.roundtrip-status');
const roundtripDiffDialog = document.querySelector(
  '#roundtrip-diff-dialog',
);
const roundtripDiffOutput = document.querySelector('#roundtrip-diff');
const roundtripDiffClose = document.querySelector('#roundtrip-diff-close');
const editorHelpOpen = document.querySelector('#editor-help-open');
const editorHelpDialog = document.querySelector('#editor-help-dialog');
const editorHelpClose = document.querySelector('#editor-help-close');
const formatControls = document.querySelectorAll(
  'input[name="yaml-format"]',
);
const formatStorageKey = 'yamlschema.yaml-format';
const legacySampleStorageKey = 'yamlschema.sample';
const sampleSourceStorageKey = 'yamlschema.sample-source';
const sampleStorageKeys = {
  ysd: 'yamlschema.sample.ysd',
  json: 'yamlschema.sample.json',
};
const sampleSelects = {
  ysd: yamlSampleSelect,
  json: jsonSampleSelect,
};
const editRootURL = new URL(
  schemaEditor.dataset.editRoot,
  window.location.href,
);
const assetURL = (path) => new URL(path, import.meta.url).href;
const sampleSources = {
  ysd: {
    person: {url: assetURL('examples/person.ysd.yaml')},
    'harbor-next': {url: assetURL('values.ysd.yaml')},
  },
  json: {
    address: {url: assetURL('examples/address.schema.json')},
    'blog-post': {url: assetURL('examples/blog-post.schema.json')},
    calendar: {url: assetURL('examples/calendar.schema.json')},
    'device-type': {url: assetURL('examples/device-type.schema.json')},
    'ecommerce-system': {
      url: assetURL('examples/ecommerce-system.schema.json'),
    },
    'geographical-location': {
      url: assetURL('examples/geographical-location.schema.json'),
    },
    'health-record': {url: assetURL('examples/health-record.schema.json')},
    'job-posting': {url: assetURL('examples/job-posting.schema.json')},
    movie: {url: assetURL('examples/movie.schema.json')},
    'user-profile': {url: assetURL('examples/user-profile.schema.json')},
    'ansible-builder': {
      url: assetURL('examples/ansible-builder.schema.json'),
    },
    'netbox-generated': {
      url: assetURL('examples/netbox-generated.schema.json'),
    },
  },
};

let timer;
let editorURLTimer;
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
let selectedSample;
let selectedSampleSource;
let documentSource;
let loadingEditorState = true;
let linkedPane;
let linkedLines;
let canonicalSourceValues = {};
const workerCalls = new Map();
const schemaWorker = new Worker(
  new URL('./schema-worker.js', import.meta.url),
);
const sharedStateResult = parseEditorState(window.location.hash);
const sharedState = sharedStateResult.ok ? sharedStateResult.state : {};
if (!sharedStateResult.ok) {
  console.warn(`Ignoring shared editor state: ${sharedStateResult.error}`);
}

const jsonEditor = new CodeEditor(jsonEditorMount, {
  language: json(),
  ariaLabel: 'JSON Schema editor',
  onChange: () => schedule(jsonEditor),
  onFocus: () => roundtripOnFocus(jsonEditor),
  onLinkedLines: (range) => linkedSelectionChanged('json', range),
});
const yamlEditor = new CodeEditor(yamlEditorMount, {
  language: yaml(),
  ariaLabel: 'YAMLSchema editor',
  onChange: () => schedule(yamlEditor),
  onFocus: () => roundtripOnFocus(yamlEditor),
  onLinkedLines: (range) => linkedSelectionChanged(yamlFormat, range),
});

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

function defaultSample(source) {
  return source === 'json' ? 'address' : 'person';
}

function loadSample(source) {
  try {
    const sample = localStorage.getItem(sampleStorageKeys[source]);
    if (Object.hasOwn(sampleSources[source], sample)) return sample;
    const legacy = localStorage.getItem(legacySampleStorageKey);
    if (Object.hasOwn(sampleSources[source], legacy)) return legacy;
    return defaultSample(source);
  } catch {
    return defaultSample(source);
  }
}

function loadSampleSource() {
  try {
    const source = localStorage.getItem(sampleSourceStorageKey);
    if (Object.hasOwn(sampleSources, source)) return source;
    const legacy = localStorage.getItem(legacySampleStorageKey);
    return Object.hasOwn(sampleSources.json, legacy) ? 'json' : 'ysd';
  } catch {
    return 'ysd';
  }
}

function saveSample(source, sample) {
  try {
    localStorage.setItem(sampleStorageKeys[source], sample);
    localStorage.setItem(sampleSourceStorageKey, source);
  } catch {
    // The selectors still work when storage is unavailable.
  }
}

function routedSampleSelection() {
  const sample = schemaEditor.dataset.schemaSlug;
  if (!sample) return undefined;
  for (const [source, samples] of Object.entries(sampleSources)) {
    if (Object.hasOwn(samples, sample)) return {source, sample};
  }
  return undefined;
}

function replaceEditorURL(sample, hash = '') {
  const url = new URL(`${sample}/`, editRootURL);
  url.hash = hash;
  window.history.replaceState(null, '', url);
}

function removeCustomOptions() {
  for (const select of Object.values(sampleSelects)) {
    select.querySelector('option[data-custom]')?.remove();
  }
}

function selectSampleSource(source, sample = loadSample(source)) {
  removeCustomOptions();
  for (const [current, select] of Object.entries(sampleSelects)) {
    select.value = current === source ? sample : '';
  }
}

function showCustomSelection(source) {
  removeCustomOptions();
  const origin = sampleSelects[selectedSampleSource].querySelector(
    `option[value="${selectedSample}"]`,
  )?.textContent.trim() || selectedSample;
  const option = document.createElement('option');
  option.value = '__custom__';
  option.textContent = `Custom from ${origin}`;
  option.dataset.custom = 'true';
  option.disabled = true;
  sampleSelects[source].insertBefore(option, sampleSelects[source].options[1]);
  option.selected = true;
  for (const [current, select] of Object.entries(sampleSelects)) {
    if (current !== source) select.value = '';
  }
}

function currentSourceContent(source) {
  if (source === 'json') return jsonEditor.value;
  return yamlFormat === 'ysd' ? yamlEditor.value : ysdValue;
}

function updateEditorURL() {
  if (loadingEditorState || !selectedSample || !documentSource) return;
  const content = currentSourceContent(documentSource);
  const custom = content === canonicalSourceValues[documentSource]
    ? undefined
    : content;
  const hash = serializeEditorState({
    source: documentSource,
    content: custom,
    pane: linkedPane,
    lines: linkedLines,
  });
  replaceEditorURL(selectedSample, hash);
  if (custom === undefined) {
    selectSampleSource(selectedSampleSource, selectedSample);
  } else {
    showCustomSelection(documentSource);
  }
}

function scheduleEditorURL() {
  clearTimeout(editorURLTimer);
  editorURLTimer = setTimeout(updateEditorURL, 250);
}

function linkedSelectionChanged(pane, range) {
  linkedPane = range ? pane : undefined;
  linkedLines = range;
  updateEditorURL();
}

function setEditorValue(editor, value) {
  updating = true;
  editor.setValue(value);
  const pane = editor === jsonEditor ? 'json' : yamlFormat;
  if (!value.startsWith('Generating ') &&
      linkedPane === pane && linkedLines) {
    const previousLines = linkedLines;
    linkedLines = editor.setLinkedLines(linkedLines);
    if (JSON.stringify(previousLines) !== JSON.stringify(linkedLines)) {
      scheduleEditorURL();
    }
  }
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
  roundtripWorker = new Worker(
    new URL('./roundtrip-worker.js', import.meta.url),
  );
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
  documentSource = 'json';
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
    updateEditorURL();
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

function closeHelpFromBackdrop(event) {
  if (event.target !== editorHelpDialog) return;
  const bounds = editorHelpDialog.getBoundingClientRect();
  const outside = event.clientX < bounds.left ||
    event.clientX > bounds.right ||
    event.clientY < bounds.top ||
    event.clientY > bounds.bottom;
  if (outside) editorHelpDialog.close();
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

async function loadSelectedSample(side = loadSampleSource()) {
  for (const select of Object.values(sampleSelects)) {
    select.disabled = true;
  }
  normalizeJsonButton.disabled = true;
  const select = sampleSelects[side];
  const sources = sampleSources[side];
  const sample = sources[select.value] || sources[defaultSample(side)];
  select.value = select.value || defaultSample(side);
  for (const [current, other] of Object.entries(sampleSelects)) {
    if (current !== side) other.value = '';
  }
  setRoundtripSource(side);
  setRoundtripStatus('checking');
  try {
    let content = sample.text;
    if (!content) {
      const response = await fetch(sample.url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      content = await response.text();
    }
    if (side === 'json') await showJsonSample(content);
    else await showSample(content);
  } catch (error) {
    cancelRoundtripStatus();
    setRoundtripStatus('unknown', 'Sample Load Error');
    const editor = side === 'json' ? jsonEditor : yamlEditor;
    const errorElement = side === 'json' ? jsonError : yamlError;
    editor.classList.add('invalid');
    errorElement.textContent = `Sample load error: ${error.message}`;
  } finally {
    for (const current of Object.values(sampleSelects)) {
      current.disabled = false;
    }
    normalizeJsonButton.disabled = !schemaWorkerReady;
  }
}

async function selectYamlFormat(format, remember = true) {
  yamlFormat = format;
  if (remember) saveYamlFormat(format);
  const readonly = format === 'ysdc';
  yamlEditor.setReadOnly(readonly);
  yamlEditor.classList.remove('invalid');
  yamlError.textContent = '';
  if (remember && linkedPane && linkedPane !== format &&
      linkedPane !== 'json') {
    yamlEditor.clearLinkedLines();
    linkedPane = undefined;
    linkedLines = undefined;
    updateEditorURL();
  }
  if (!schemaWorkerReady) return;
  if (format === 'ysd' && ysdValue) setEditorValue(yamlEditor, ysdValue);
  else {
    showGeneratingYSDC();
    await convertJsonToYaml(false, false);
  }
}

function schedule(editor) {
  const source = editor === jsonEditor ? 'json' : 'ysd';
  documentSource = source;
  setRoundtripSource(source);
  conversionRequest++;
  cancelRoundtripStatus();
  clearTimeout(timer);
  clearTimeout(checkingTimer);
  checkingTimer = setTimeout(() => {
    setRoundtripStatus('checking');
  }, 200);
  timer = setTimeout(() => convertFrom(editor), 250);
  scheduleEditorURL();
}

for (const indicator of roundtripStatuses) {
  indicator.addEventListener('click', showRoundtripDiff);
}
roundtripDiffDialog.addEventListener('click', closeDiffFromBackdrop);
roundtripDiffClose.addEventListener('click', () => {
  roundtripDiffDialog.close();
});
editorHelpOpen.addEventListener('click', (event) => {
  event.preventDefault();
  editorHelpDialog.showModal();
});
editorHelpDialog.addEventListener('click', closeHelpFromBackdrop);
editorHelpClose.addEventListener('click', () => {
  editorHelpDialog.close();
});
normalizeJsonButton.addEventListener('click', () => {
  void normalizeJsonSchema();
});
const requestedSample = routedSampleSelection();
const initialSampleSource = requestedSample?.source || loadSampleSource();
const initialSample = requestedSample?.sample ||
  loadSample(initialSampleSource);
if (requestedSample) saveSample(requestedSample.source, requestedSample.sample);
selectedSampleSource = initialSampleSource;
selectedSample = initialSample;
documentSource = initialSampleSource;
selectSampleSource(initialSampleSource, initialSample);
replaceEditorURL(
  initialSample,
  sharedStateResult.ok ? window.location.hash : '',
);
for (const [source, select] of Object.entries(sampleSelects)) {
  select.addEventListener('change', async () => {
    loadingEditorState = true;
    saveSample(source, select.value);
    selectedSampleSource = source;
    selectedSample = select.value;
    documentSource = source;
    canonicalSourceValues = {};
    linkedPane = undefined;
    linkedLines = undefined;
    jsonEditor.clearLinkedLines();
    yamlEditor.clearLinkedLines();
    replaceEditorURL(select.value);
    cancelRoundtripStatus();
    clearTimeout(checkingTimer);
    await loadSelectedSample(source);
    canonicalSourceValues = {
      ysd: ysdValue,
      json: jsonEditor.value,
    };
    loadingEditorState = false;
    updateEditorURL();
  });
}
for (const control of formatControls) {
  control.checked = control.value === yamlFormat;
  control.addEventListener('change', () => {
    if (control.checked) void selectYamlFormat(control.value);
  });
}
void selectYamlFormat(yamlFormat, false);

async function initializeEditor() {
  await loadSelectedSample(initialSampleSource);
  canonicalSourceValues = {
    ysd: ysdValue,
    json: jsonEditor.value,
  };

  if (sharedState.content !== undefined) {
    documentSource = sharedState.source;
    if (sharedState.source === 'json') {
      await showJsonSample(sharedState.content);
    } else {
      await showSample(sharedState.content);
    }
  }

  if (sharedState.pane && sharedState.lines) {
    if (sharedState.pane === 'ysd' || sharedState.pane === 'ysdc') {
      await selectYamlFormat(sharedState.pane, false);
      for (const control of formatControls) {
        control.checked = control.value === yamlFormat;
      }
      linkedPane = sharedState.pane;
      linkedLines = yamlEditor.setLinkedLines(sharedState.lines, true);
    } else {
      linkedPane = 'json';
      linkedLines = jsonEditor.setLinkedLines(sharedState.lines, true);
    }
  }

  loadingEditorState = false;
  updateEditorURL();
}

schemaWorker.addEventListener('message', ({data}) => {
  if (data.type === 'ready') {
    schemaWorkerReady = true;
    normalizeJsonButton.disabled = false;
    void initializeEditor();
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
