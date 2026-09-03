import {json} from '@codemirror/lang-json';
import {yaml} from '@codemirror/lang-yaml';

import {
  prepareJsonSchemaInput,
} from '../../docs/assets/editor/json.js';
import {CodeEditor} from './editor.js';
import {ResultCache, resultCacheKey} from './result-cache.js';
import {parseEditorState, serializeEditorState} from './url-state.js';

const schemaEditor = document.querySelector('.schema-editor');
const jsonEditorMount = document.querySelector('#json-schema');
const yamlEditorMount = document.querySelector('#yaml-schema');
const jsonError = document.querySelector('#json-error');
const yamlError = document.querySelector('#yaml-error');
const yamlSampleSelect = document.querySelector('#yaml-sample-select');
const jsonSampleSelect = document.querySelector('#json-sample-select');
const jsonSchemaTitle = document.querySelector('#json-schema-title');
const editorSettingsOpen = document.querySelector('#editor-settings-open');
const editorSettingsDialog = document.querySelector(
  '#editor-settings-dialog',
);
const editorSettingsClose = document.querySelector('#editor-settings-close');
const scrollSyncControl = document.querySelector('#scroll-sync');
const scrollSyncSourceControl = document.querySelector(
  '#scroll-sync-source',
);
const scrollSyncSourceControls = document.querySelectorAll(
  'input[name="scroll-sync-source"]',
);
const ysdcJsonControl = document.querySelector('#ysdc-json');
const factoryResetControl = document.querySelector('#factory-reset');
const editorShare = document.querySelector('#editor-share');
const editorShareStatus = document.querySelector('#editor-share-status');
const editorCopyButtons = document.querySelectorAll('.editor-copy');
const roundtripStatuses = document.querySelectorAll('.roundtrip-status');
const roundtripDiffDialog = document.querySelector(
  '#roundtrip-diff-dialog',
);
const roundtripDiffTitle = document.querySelector('#roundtrip-diff-title');
const roundtripDiffOutput = document.querySelector('#roundtrip-diff');
const roundtripDiffCopy = document.querySelector('#roundtrip-diff-copy');
const roundtripDiffClose = document.querySelector('#roundtrip-diff-close');
const editorHelpOpenControls = document.querySelectorAll(
  '[data-editor-help-open]',
);
const editorHelpDialog = document.querySelector('#editor-help-dialog');
const editorHelpClose = document.querySelector('#editor-help-close');
const yamlFormatControls = document.querySelectorAll(
  'input[name="yaml-format"]',
);
const ysdStrictControl = document.querySelector('#ysd-strict');
const jsonNormalControl = document.querySelector('#json-normal');
const formatStorageKey = 'yamlschema.yaml-format';
const scrollSyncStorageKey = 'yamlschema.scroll-sync';
const scrollSyncSourceStorageKey = 'yamlschema.scroll-sync-source';
const ysdcJsonStorageKey = 'yamlschema.ysdc-json';
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
    yamlschema: {url: assetURL('examples/yamlschema.ysd.yaml')},
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
    'harbor-next': {
      url: assetURL('examples/harbor-next.schema.json'),
    },
    'openqa-job-templates': {
      url: assetURL('examples/openqa-job-templates.schema.yaml'),
    },
    'openapi-3-schema': {
      url: assetURL('examples/openapi-3-schema.schema.json'),
    },
    petstore: {url: assetURL('examples/petstore.schema.json')},
    'netbox-generated': {
      url: assetURL('examples/netbox-generated.schema.json'),
    },
  },
};
const workerResultCache = new ResultCache();
const roundtripResultCache = new ResultCache();

let timer;
let editorURLTimer;
let checkingTimer;
let roundtripTimer;
let roundtripWorker;
let roundtripBusy = false;
let roundtripRequest = 0;
let roundtripRequestKey;
let roundtripSource;
let conversionRequest = 0;
let jsonNormalRequest = 0;
let workerRequest = 0;
let schemaWorkerReady = false;
let updating = false;
let yamlFormat = loadYamlFormat();
let ysdStrict = false;
let ysdStrictReady = false;
let jsonNormal = false;
let ysdValue = '';
let jsonValue = '';
let jsonSerialization = 'json';
let roundtripDiff = '';
let roundtripDiffFilename = '';
let selectedSample;
let selectedSampleSource;
let documentSource;
let loadingEditorState = true;
let linkedPane;
let linkedLines;
let canonicalSourceValues = {};
let scrollSyncFrame;
let scrollSyncEnabled = loadScrollSync();
let scrollSyncSource = loadScrollSyncSource();
let ysdcJson = loadYSDCJson();
let shareStatusTimer;
const editorCopyTimers = new WeakMap();
const workerCalls = new Map();
const schemaWorker = new Worker(
  new URL('./schema-worker.js?v=20', import.meta.url),
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
  onFocus: () => editorFocused(jsonEditor),
  onLinkedLines: (range) => linkedSelectionChanged('json', range),
  onScroll: () => scheduleScrollSync(jsonEditor),
});
const yamlEditor = new CodeEditor(yamlEditorMount, {
  language: yaml(),
  ariaLabel: 'YAMLSchema editor',
  onChange: () => schedule(yamlEditor),
  onFocus: () => editorFocused(yamlEditor),
  onLinkedLines: (range) => linkedSelectionChanged(yamlFormat, range),
  onScroll: () => scheduleScrollSync(yamlEditor),
});

function loadScrollSync() {
  try {
    return localStorage.getItem(scrollSyncStorageKey) !== 'false';
  } catch {
    return true;
  }
}

function saveScrollSync(enabled) {
  try {
    localStorage.setItem(scrollSyncStorageKey, String(enabled));
  } catch {
    // Scroll sync still works when storage is unavailable.
  }
}

function loadScrollSyncSource() {
  try {
    const source = localStorage.getItem(scrollSyncSourceStorageKey);
    return ['ysd', 'json', 'current'].includes(source) ? source : 'ysd';
  } catch {
    return 'ysd';
  }
}

function saveScrollSyncSource(source) {
  try {
    localStorage.setItem(scrollSyncSourceStorageKey, source);
  } catch {
    // Scroll sync still works when storage is unavailable.
  }
}

function updateScrollSyncControls() {
  scrollSyncControl.checked = scrollSyncEnabled;
  scrollSyncSourceControl.disabled = !scrollSyncEnabled;
  for (const control of scrollSyncSourceControls) {
    control.checked = control.value === scrollSyncSource;
  }
}

function editorFocused(editor) {
  const editableJson = editor === jsonEditor;
  const editableYSD = editor === yamlEditor && yamlFormat === 'ysd';
  if (!updating && (editableJson || editableYSD)) {
    const source = editor === jsonEditor ? 'json' : 'ysd';
    documentSource = source;
    updateYSDStrictControl();
    if (source !== selectedSampleSource) {
      delete canonicalSourceValues[source];
    }
    scheduleEditorURL();
  }
  roundtripOnFocus(editor);
}

function scrollSyncSourceEditor() {
  if (scrollSyncSource === 'json') return jsonEditor;
  if (scrollSyncSource === 'ysd') return yamlEditor;
  if (scrollSyncSource === 'current' && roundtripSource === 'json') {
    return jsonEditor;
  }
  if (scrollSyncSource === 'current' && roundtripSource === 'ysd') {
    return yamlEditor;
  }
  return undefined;
}

function synchronizeScroll(editor) {
  if (!scrollSyncEnabled || editor !== scrollSyncSourceEditor()) return;
  const sourceFormat = editor === jsonEditor
    ? jsonPaneFormat()
    : yamlPaneFormat();
  const target = editor === jsonEditor ? yamlEditor : jsonEditor;
  const targetFormat = target === jsonEditor
    ? jsonPaneFormat()
    : yamlPaneFormat();
  target.scrollToSchemaLocation(
    editor.schemaLocation(sourceFormat),
    targetFormat,
  );
}

function scheduleScrollSync(editor) {
  if (loadingEditorState || !scrollSyncEnabled ||
      editor !== scrollSyncSourceEditor()) return;
  cancelAnimationFrame(scrollSyncFrame);
  scrollSyncFrame = requestAnimationFrame(() => synchronizeScroll(editor));
}

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

function loadYSDCJson() {
  try {
    return localStorage.getItem(ysdcJsonStorageKey) === 'true';
  } catch {
    return false;
  }
}

function saveYSDCJson(enabled) {
  try {
    localStorage.setItem(ysdcJsonStorageKey, String(enabled));
  } catch {
    // The display option still works when storage is unavailable.
  }
}

function yamlPaneFormat() {
  return yamlFormat === 'ysdc' && ysdcJson ? 'ysdc-json' : yamlFormat;
}

function jsonPaneFormat() {
  return jsonSerialization === 'yaml' ? 'jsc-yaml' : 'json';
}

function setJsonSerialization(serialization) {
  if (serialization === jsonSerialization) return;
  jsonSerialization = serialization;
  const language = serialization === 'yaml' ? yaml() : json();
  jsonEditor.setLanguage(language);
}

function jsonSchemaOutputOperation(operation) {
  return jsonSerialization === 'yaml' ? `${operation}-yaml` : operation;
}

function prepareJsonSchema(text) {
  const input = prepareJsonSchemaInput(text);
  setJsonSerialization(input.serialization);
  return input.text;
}

function strictImportEnabled() {
  return documentSource === 'json' && ysdStrict;
}

function currentYSDOperation() {
  return strictImportEnabled()
    ? 'json-schema-to-ysd-strict'
    : 'json-schema-to-ysd';
}

function currentYSDCOperation() {
  const strict = strictImportEnabled() ? '-strict' : '';
  return ysdcJson
    ? `json-schema-to-ysdc-json${strict}`
    : `json-schema-to-ysdc${strict}`;
}

function updateYamlEditorLanguage() {
  const language = yamlPaneFormat() === 'ysdc-json' ? json() : yaml();
  yamlEditor.setLanguage(language);
}

function setJsonNormal(normal) {
  jsonNormal = normal;
  jsonNormalControl.checked = normal;
}

function updateYSDStrictControl() {
  ysdStrictControl.checked = ysdStrict;
  ysdStrictControl.disabled =
    !schemaWorkerReady || documentSource !== 'json' ||
    !ysdStrictReady;
  ysdStrictControl.setAttribute(
    'aria-disabled',
    String(ysdStrictControl.disabled || ysdStrict),
  );
}

function setYSDStrict(strict) {
  ysdStrict = strict;
  updateYSDStrictControl();
}

function setYSDStrictReady(ready) {
  ysdStrictReady = ready;
  updateYSDStrictControl();
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

function editorURL(sample, hash = '') {
  const url = sample
    ? new URL(`${sample}/`, editRootURL)
    : new URL(editRootURL);
  url.hash = hash;
  return url;
}

function replaceEditorURL(sample, hash = '') {
  const url = editorURL(sample, hash);
  window.history.replaceState(null, '', url);
}

function redirectEditorURL(sample, hash = '') {
  const url = editorURL(sample, hash);
  window.location.replace(url.href);
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
  if (source === 'json') return jsonValue;
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
    normal: documentSource === 'json' && jsonNormal
      ? true
      : undefined,
    strict: documentSource === 'json' && ysdStrict
      ? true
      : undefined,
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

function setShareStatus(message) {
  clearTimeout(shareStatusTimer);
  editorShareStatus.textContent = message;
  if (message) {
    shareStatusTimer = setTimeout(() => {
      editorShareStatus.textContent = '';
    }, 2500);
  }
}

async function copyText(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const input = document.createElement('textarea');
  input.value = text;
  input.setAttribute('readonly', '');
  input.style.position = 'fixed';
  input.style.opacity = '0';
  document.body.append(input);
  input.select();
  const copied = document.execCommand('copy');
  input.remove();
  if (!copied) throw new Error('Copy failed');
}

function setEditorCopyStatus(button, copied) {
  const label = button.dataset.copyLabel;
  const message = copied ? `${label} copied` : `Unable to copy ${label}`;
  button.title = message;
  button.setAttribute('aria-label', message);
  button.classList.remove('copied');
  if (copied) {
    void button.offsetWidth;
    button.classList.add('copied');
  }
  clearTimeout(editorCopyTimers.get(button));
  editorCopyTimers.set(button, setTimeout(() => {
    button.title = 'Copy text';
    button.setAttribute('aria-label', `Copy ${label}`);
    button.classList.remove('copied');
  }, 2000));
}

async function copyEditorText(button) {
  const editor = button.dataset.copyEditor === 'json'
    ? jsonEditor
    : yamlEditor;
  try {
    await copyText(editor.value);
    setEditorCopyStatus(button, true);
  } catch {
    setEditorCopyStatus(button, false);
  }
}

async function copyRoundtripDiff() {
  try {
    await copyText(roundtripDiff);
    setEditorCopyStatus(roundtripDiffCopy, true);
  } catch {
    setEditorCopyStatus(roundtripDiffCopy, false);
  }
}

async function shareEditorURL() {
  updateEditorURL();
  const url = window.location.href;
  try {
    if (navigator.share) {
      await navigator.share({title: 'YAMLSchema', url});
      return;
    }
    await copyText(url);
    setShareStatus('Link copied');
  } catch (error) {
    if (error.name !== 'AbortError') setShareStatus('Unable to share link');
  }
}

function linkedSelectionChanged(pane, range) {
  linkedPane = range ? pane : undefined;
  linkedLines = range;
  updateEditorURL();
}

function setEditorValue(editor, value) {
  updating = true;
  if (editor === jsonEditor && !value.startsWith('Generating ')) {
    prepareJsonSchema(value);
  }
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
    setEditorValue(yamlEditor, 'Generating .ysdc...');
  }
}

function showGeneratingYamlSchema() {
  const name = yamlFormat === 'ysdc' ? '.ysdc' : '.ysd';
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
    unknown: ['?', 'JSON Schema Input Error'],
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

function setRoundtripDiff(diff, filename = '') {
  roundtripDiff = diff;
  roundtripDiffFilename = diff ? filename : '';
  roundtripDiffTitle.textContent = roundtripDiffFilename
    ? `Roundtrip diff for ${roundtripDiffFilename}`
    : 'Roundtrip diff';
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
  jsonNormalControl.disabled = true;
  ysdStrictControl.disabled = true;
  for (const resolve of workerCalls.values()) {
    resolve({ok: false, error: message});
  }
  workerCalls.clear();
  workerResultCache.clear();
  cancelRoundtripStatus();
  setRoundtripStatus('unknown', 'Conversion Worker Error');
  jsonEditor.classList.add('invalid');
  jsonError.textContent = message;
}

function cachedWorkerResult(operation, input) {
  return workerResultCache.get(resultCacheKey(operation, input))?.result;
}

function callWorker(operation, input) {
  const key = resultCacheKey(operation, input);
  const cached = workerResultCache.get(key);
  if (cached) return cached.promise;
  const entry = {};
  const pending = new Promise((resolve) => {
    const id = ++workerRequest;
    workerCalls.set(id, resolve);
    schemaWorker.postMessage({type: 'call', id, operation, input});
  });
  entry.promise = pending.then((result) => {
    entry.result = result;
    return result;
  });
  workerResultCache.set(key, entry);
  return entry.promise;
}

function getRoundtripWorker() {
  if (roundtripWorker) return roundtripWorker;
  roundtripWorker = new Worker(
    new URL('./roundtrip-worker.js?v=20', import.meta.url),
  );
  roundtripWorker.addEventListener('message', ({data}) => {
    if (data.id !== undefined && data.id !== roundtripRequest) return;
    roundtripBusy = false;
    if (data.type === 'error') {
      setRoundtripDiff('');
      setRoundtripStatus('unknown', 'Roundtrip Check Error');
    } else {
      const result = {
        works: data.works,
        diff: data.diff || '',
        filename: data.filename,
      };
      roundtripResultCache.set(roundtripRequestKey, result);
      showRoundtripResult(result);
    }
  });
  roundtripWorker.addEventListener('error', () => {
    roundtripBusy = false;
    roundtripResultCache.clear();
    setRoundtripDiff('');
    setRoundtripStatus('unknown', 'Roundtrip Check Error');
  });
  return roundtripWorker;
}

function showRoundtripResult(result) {
  setRoundtripDiff(result.diff, result.filename);
  setRoundtripStatus(result.works ? 'works' : 'fails');
}

function roundtripFilename(source) {
  const sample = sampleSources[source]?.[selectedSample];
  if (sample?.url) {
    const path = new URL(sample.url).pathname;
    return decodeURIComponent(path.split('/').pop());
  }
  const suffix = source === 'json' ? 'schema.json' : 'ysd.yaml';
  return `${selectedSample}.${suffix}`;
}

function updateRoundtripStatus(source, input, delay = 500) {
  setRoundtripSource(source);
  const filename = roundtripFilename(source);
  const key = resultCacheKey([source, filename], input);
  const cached = roundtripResultCache.get(key);
  if (cached) {
    if (key !== roundtripRequestKey) cancelRoundtripStatus();
    roundtripRequestKey = key;
    showRoundtripResult(cached);
    return;
  }
  const pending = key === roundtripRequestKey &&
    (roundtripBusy || roundtripTimer !== undefined);
  if (pending) return;
  cancelRoundtripStatus();
  const id = ++roundtripRequest;
  roundtripRequestKey = key;
  roundtripTimer = setTimeout(() => {
    roundtripTimer = undefined;
    roundtripBusy = true;
    getRoundtripWorker().postMessage({id, source, input, filename});
  }, delay);
}

function cancelRoundtripStatus() {
  clearTimeout(roundtripTimer);
  roundtripTimer = undefined;
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
    scheduleScrollSync(source);
  } else {
    source.classList.add('invalid');
    sourceError.textContent = result.error;
  }
}

async function convertJsonToYaml(
  updateYSD = true,
  checkRoundtrip = true,
) {
  const input = prepareJsonSchema(jsonValue);
  const id = ++conversionRequest;
  const ysdOperation = currentYSDOperation();
  const ysdcOperation = currentYSDCOperation();
  const cachedYSD = cachedWorkerResult(ysdOperation, input);
  const cachedYSDC = cachedWorkerResult(ysdcOperation, input);
  const cachedVisible = yamlFormat === 'ysdc' ? cachedYSDC : cachedYSD;
  if (!cachedVisible) showGeneratingYamlSchema();
  if (checkRoundtrip) updateRoundtripStatus('json', input);
  const [toYSD, toYSDC] = await Promise.all([
    cachedYSD || callWorker(ysdOperation, input),
    cachedYSDC || callWorker(ysdcOperation, input),
  ]);
  if (id !== conversionRequest) return;
  if (!toYSD.ok) {
    showResult(jsonEditor, yamlEditor, jsonError, yamlError, toYSD);
    setYSDStrictReady(false);
    return toYSD;
  }
  const convertedYSD = toYSD.value.replace(
    /^# Converted from JSON Schema\r?\n/,
    '',
  );
  if (updateYSD) ysdValue = convertedYSD;
  let result = {...toYSD, value: convertedYSD};
  if (yamlFormat === 'ysdc') {
    result = toYSDC;
  }
  showResult(jsonEditor, yamlEditor, jsonError, yamlError, result);
  if (documentSource === 'json') setYSDStrictReady(true);
  return {
    ok: true,
    ysd: convertedYSD,
    visible: result,
  };
}

async function makeJsonSchemaStrict() {
  if (!schemaWorkerReady || updating || documentSource !== 'json' ||
      !ysdStrictReady || ysdStrict) {
    updateYSDStrictControl();
    return;
  }
  const sourceValue = jsonValue;
  const canonicalSource = sourceValue === canonicalSourceValues.json;
  jsonNormalRequest++;
  setJsonNormal(false);
  setYSDStrictReady(false);
  setYSDStrict(true);
  jsonNormalControl.disabled = true;
  clearTimeout(timer);
  clearTimeout(checkingTimer);
  cancelRoundtripStatus();
  setRoundtripSource('json');
  setRoundtripStatus('checking');
  const conversion = await convertJsonToYaml(true, false);
  if (!conversion?.ok || jsonValue !== sourceValue) {
    if (jsonValue === sourceValue) {
      setYSDStrict(false);
      setYSDStrictReady(false);
      jsonNormalControl.disabled = !schemaWorkerReady;
    }
    return conversion;
  }
  const id = conversionRequest;
  const operation = jsonSchemaOutputOperation('ysd-to-json-schema');
  const cached = cachedWorkerResult(operation, conversion.ysd);
  showGeneratingJSONSchema();
  const result = cached || await callWorker(operation, conversion.ysd);
  if (id !== conversionRequest || jsonValue !== sourceValue) return result;
  if (!result.ok) {
    jsonEditor.classList.add('invalid');
    jsonError.textContent = result.error;
    setRoundtripStatus('unknown', 'Strict JSON Schema Error');
    setYSDStrict(false);
    setYSDStrictReady(true);
    jsonNormalControl.disabled = !schemaWorkerReady;
    return result;
  }
  jsonEditor.classList.remove('invalid');
  jsonError.textContent = '';
  jsonValue = result.value;
  setEditorValue(jsonEditor, jsonValue);
  if (canonicalSource) canonicalSourceValues.json = jsonValue;
  setJsonNormal(true);
  jsonNormalControl.disabled = !schemaWorkerReady;
  updateRoundtripStatus('json', prepareJsonSchema(jsonValue));
  updateYSDStrictControl();
  updateEditorURL();
  return result;
}

async function normalizeJsonSchema() {
  if (!schemaWorkerReady || updating || jsonNormal) {
    jsonNormalControl.checked = jsonNormal;
    return;
  }
  const sourceValue = jsonValue;
  const id = ++jsonNormalRequest;
  conversionRequest++;
  clearTimeout(timer);
  clearTimeout(checkingTimer);
  documentSource = 'json';
  setJsonNormal(false);
  setYSDStrict(false);
  setYSDStrictReady(false);
  jsonNormalControl.disabled = true;
  cancelRoundtripStatus();
  setRoundtripSource('json');
  setRoundtripStatus('checking');
  const input = prepareJsonSchema(sourceValue);
  const operation = jsonSchemaOutputOperation('json-schema-normalize');
  const cached = cachedWorkerResult(operation, input);
  const result = cached || await callWorker(operation, input);
  if (id !== jsonNormalRequest || jsonValue !== sourceValue) return result;
  if (!result.ok) {
    jsonEditor.classList.add('invalid');
    jsonError.textContent = result.error;
    setRoundtripStatus('unknown', 'JSON Schema Normalize Error');
    jsonNormalControl.disabled = !schemaWorkerReady;
    return result;
  }
  jsonEditor.classList.remove('invalid');
  jsonError.textContent = '';
  jsonValue = result.value;
  setEditorValue(jsonEditor, jsonValue);
  setJsonNormal(true);
  await convertJsonToYaml();
  if (id !== jsonNormalRequest) return result;
  jsonNormalControl.disabled = !schemaWorkerReady;
  updateEditorURL();
  return result;
}

async function convertYamlToJson() {
  const id = ++conversionRequest;
  const ysd = yamlEditor.value;
  ysdValue = ysd;
  jsonNormalRequest++;
  setJsonNormal(false);
  jsonNormalControl.disabled = true;
  setJsonSerialization('json');
  const operation = 'ysd-to-json-schema';
  const cached = cachedWorkerResult(operation, ysd);
  if (!cached) showGeneratingJSONSchema();
  const result = cached || await callWorker(operation, ysd);
  if (id !== conversionRequest) return;
  if (result.ok) {
    yamlEditor.classList.remove('invalid');
    jsonEditor.classList.remove('invalid');
    yamlError.textContent = '';
    jsonError.textContent = '';
    jsonValue = result.value;
    setEditorValue(jsonEditor, jsonValue);
    setJsonNormal(true);
    jsonNormalControl.disabled = !schemaWorkerReady;
    scheduleScrollSync(yamlEditor);
    updateRoundtripStatus('ysd', ysd);
  } else {
    showResult(yamlEditor, jsonEditor, yamlError, jsonError, result);
    jsonNormalControl.disabled = !schemaWorkerReady;
    cancelRoundtripStatus();
    setRoundtripStatus('unknown', 'YAML Schema Error');
  }
  return result;
}

function convertFrom(editor) {
  if (!schemaWorkerReady || updating) return;
  if (editor === jsonEditor) {
    void convertJsonToYaml();
  } else if (yamlFormat === 'ysd') {
    void convertYamlToJson();
  }
}

function roundtripOnFocus(editor) {
  if (!schemaWorkerReady || updating) return;
  if (editor === yamlEditor && yamlFormat !== 'ysd') return;
  const source = editor === jsonEditor ? 'json' : 'ysd';
  clearTimeout(checkingTimer);
  setRoundtripSource(source);
  setRoundtripStatus('checking');
  if (editor === yamlEditor) {
    updateRoundtripStatus('ysd', yamlEditor.value, 0);
    return;
  }
  const input = prepareJsonSchema(jsonValue);
  updateRoundtripStatus('json', input, 0);
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

function closeSettingsFromBackdrop(event) {
  if (event.target !== editorSettingsDialog) return;
  const bounds = editorSettingsDialog.getBoundingClientRect();
  const outside = event.clientX < bounds.left ||
    event.clientX > bounds.right ||
    event.clientY < bounds.top ||
    event.clientY > bounds.bottom;
  if (outside) editorSettingsDialog.close();
}

function siteCookiePaths() {
  const paths = ['/'];
  const parts = window.location.pathname.split('/').filter(Boolean);
  let path = '';
  for (const part of parts) {
    path += `/${part}`;
    paths.push(path, `${path}/`);
  }
  return [...new Set(paths)];
}

function deleteSiteCookies() {
  const names = document.cookie.split(';')
    .map((cookie) => cookie.split('=', 1)[0].trim())
    .filter(Boolean);
  const hostname = window.location.hostname;
  const domains = ['', hostname, `.${hostname}`];
  const secure = window.location.protocol === 'https:' ? '; Secure' : '';
  for (const name of names) {
    for (const path of siteCookiePaths()) {
      for (const domain of domains) {
        const domainAttribute = domain ? `; Domain=${domain}` : '';
        document.cookie = `${name}=; Max-Age=0; Expires=Thu, 01 Jan 1970 ` +
          `00:00:00 GMT; Path=${path}${domainAttribute}${secure}`;
      }
    }
  }
}

function clearSiteCookies() {
  deleteSiteCookies();
  window.location.assign('https://yamlschema.org/demo/');
}

function factoryResetSite() {
  try {
    localStorage.clear();
  } catch {
    // Continue resetting the site when storage is unavailable.
  }
  try {
    sessionStorage.clear();
  } catch {
    // Continue resetting the site when storage is unavailable.
  }
  deleteSiteCookies();
  window.location.assign(editRootURL.href);
}

function cachedYSDCForYSD(ysd) {
  const json = cachedWorkerResult('ysd-to-json-schema', ysd);
  if (!json?.ok) return undefined;
  return cachedWorkerResult(
    currentYSDCOperation(),
    prepareJsonSchemaInput(json.value).text,
  );
}

async function showSample(ysd) {
  ysdValue = ysd;
  setEditorValue(yamlEditor, ysdValue);
  const cachedYSDC = yamlFormat === 'ysdc' && cachedYSDCForYSD(ysd);
  const conversion = convertYamlToJson();
  if (yamlFormat === 'ysdc' && !cachedYSDC) showGeneratingYSDC();
  const result = await conversion;
  if (yamlFormat === 'ysdc' && result?.ok) {
    await convertJsonToYaml(false, false);
  }
}

async function showJsonSample(json, normal = false) {
  jsonValue = json;
  jsonNormalRequest++;
  setYSDStrictReady(false);
  setEditorValue(jsonEditor, jsonValue);
  setJsonNormal(normal);
  await convertJsonToYaml();
}

async function loadSelectedSample(
  side = loadSampleSource(),
  normal = false,
) {
  conversionRequest++;
  jsonNormalRequest++;
  for (const select of Object.values(sampleSelects)) {
    select.disabled = true;
  }
  jsonNormalControl.disabled = true;
  ysdStrictControl.disabled = true;
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
    if (side === 'json') await showJsonSample(content, normal);
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
    jsonNormalControl.disabled = !schemaWorkerReady;
    updateYSDStrictControl();
  }
}

async function selectYamlFormat(format, remember = true) {
  yamlFormat = format;
  if (remember) saveYamlFormat(format);
  updateYamlEditorLanguage();
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
    await convertJsonToYaml(false, false);
  }
}

function schedule(editor) {
  const source = editor === jsonEditor ? 'json' : 'ysd';
  jsonNormalRequest++;
  setJsonNormal(false);
  setYSDStrict(false);
  setYSDStrictReady(false);
  if (source === 'json') {
    jsonValue = jsonEditor.value;
    prepareJsonSchema(jsonValue);
    jsonNormalControl.disabled = !schemaWorkerReady;
  } else {
    jsonNormalControl.disabled = true;
  }
  documentSource = source;
  updateYSDStrictControl();
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
roundtripDiffCopy.addEventListener('click', () => {
  void copyRoundtripDiff();
});
roundtripDiffClose.addEventListener('click', () => {
  roundtripDiffDialog.close();
});
for (const control of editorHelpOpenControls) {
  control.addEventListener('click', (event) => {
    event.preventDefault();
    editorHelpDialog.showModal();
  });
}
editorHelpDialog.addEventListener('click', closeHelpFromBackdrop);
editorHelpClose.addEventListener('click', () => {
  editorHelpDialog.close();
});
editorSettingsOpen.addEventListener('click', () => {
  editorSettingsDialog.showModal();
});
editorSettingsDialog.addEventListener('click', closeSettingsFromBackdrop);
editorSettingsClose.addEventListener('click', () => {
  editorSettingsDialog.close();
});
editorShare.addEventListener('click', () => {
  void shareEditorURL();
});
for (const button of editorCopyButtons) {
  button.addEventListener('click', () => {
    void copyEditorText(button);
  });
}
updateScrollSyncControls();
scrollSyncControl.addEventListener('change', () => {
  scrollSyncEnabled = scrollSyncControl.checked;
  saveScrollSync(scrollSyncEnabled);
  updateScrollSyncControls();
  const source = scrollSyncSourceEditor();
  if (scrollSyncEnabled && source) synchronizeScroll(source);
});
for (const control of scrollSyncSourceControls) {
  control.addEventListener('change', () => {
    if (!control.checked) return;
    scrollSyncSource = control.value;
    saveScrollSyncSource(scrollSyncSource);
    const source = scrollSyncSourceEditor();
    if (scrollSyncEnabled && source) synchronizeScroll(source);
  });
}
ysdcJsonControl.checked = ysdcJson;
ysdcJsonControl.addEventListener('change', () => {
  ysdcJson = ysdcJsonControl.checked;
  saveYSDCJson(ysdcJson);
  updateYamlEditorLanguage();
  if (yamlFormat === 'ysdc' && schemaWorkerReady) {
    void convertJsonToYaml(false, false);
  }
});
factoryResetControl.addEventListener('click', factoryResetSite);
ysdStrictControl.addEventListener('click', (event) => {
  if (ysdStrict) {
    event.preventDefault();
    ysdStrictControl.checked = true;
    return;
  }
  if (!ysdStrictControl.checked) return;
  ysdStrictControl.checked = false;
  void makeJsonSchemaStrict();
});
jsonSchemaTitle.addEventListener('dblclick', clearSiteCookies);
jsonNormalControl.addEventListener('click', (event) => {
  if (jsonNormal) {
    event.preventDefault();
    jsonNormalControl.checked = true;
    return;
  }
  if (!jsonNormalControl.checked) return;
  jsonNormalControl.checked = false;
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
const initialHash = sharedStateResult.ok ? window.location.hash : '';
if (requestedSample) {
  replaceEditorURL(initialSample, initialHash);
} else {
  redirectEditorURL(initialSample, initialHash);
}
for (const [source, select] of Object.entries(sampleSelects)) {
  select.addEventListener('change', async () => {
    loadingEditorState = true;
    saveSample(source, select.value);
    selectedSampleSource = source;
    selectedSample = select.value;
    documentSource = source;
    setYSDStrict(false);
    setYSDStrictReady(false);
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
      json: jsonValue,
    };
    loadingEditorState = false;
    updateEditorURL();
  });
}
for (const control of yamlFormatControls) {
  control.checked = control.value === yamlFormat;
  control.addEventListener('change', () => {
    if (control.checked) void selectYamlFormat(control.value);
  });
}
void selectYamlFormat(yamlFormat, false);

async function initializeEditor() {
  const initialSource = sharedState.content !== undefined
    ? sharedState.source
    : initialSampleSource;
  const initialStrict =
    initialSource === 'json' && sharedState.strict === true;
  setYSDStrict(
    initialStrict && sharedState.content !== undefined,
  );
  if (sharedState.content !== undefined) {
    documentSource = sharedState.source;
    canonicalSourceValues = {};
    if (sharedState.source === 'json') {
      await showJsonSample(sharedState.content, sharedState.normal === true);
    } else {
      await showSample(sharedState.content);
    }
  } else {
    await loadSelectedSample(
      initialSampleSource,
      initialSampleSource === 'json' && sharedState.normal === true,
    );
    if (initialStrict) await makeJsonSchemaStrict();
    canonicalSourceValues = {
      ysd: ysdValue,
      json: jsonValue,
    };
  }
  for (const select of Object.values(sampleSelects)) {
    select.disabled = false;
  }

  if (sharedState.pane && sharedState.lines) {
    if (sharedState.pane === 'ysd' || sharedState.pane === 'ysdc') {
      await selectYamlFormat(sharedState.pane, false);
      for (const control of yamlFormatControls) {
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
    jsonNormalControl.disabled = false;
    updateYSDStrictControl();
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
