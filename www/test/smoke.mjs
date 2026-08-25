import '../docs/assets/editor/wasm_exec.js';
import {json as jsonLanguage} from '@codemirror/lang-json';
import {yaml as yamlLanguage} from '@codemirror/lang-yaml';
import {EditorState} from '@codemirror/state';
import {readFile} from 'node:fs/promises';
import {normalizeJson} from '../docs/assets/editor/json.js';
import {schemaSections} from '../src/editor/schema-sections.js';
import {
  clampLineRange,
  decodeContent,
  encodeContent,
  nextLineRange,
  parseEditorState,
  parseLineRange,
  serializeEditorState,
} from '../src/editor/url-state.js';
await import('../docs/assets/editor/unified-diff.js');

const sectionJSON = EditorState.create({
  doc: `{
  "$defs": {"thing": {"type": "string"}},
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  }
}`,
  extensions: [jsonLanguage()],
});
const sectionYSD = EditorState.create({
  doc: `+thing: +Str
name: +Str
age?: +Int
`,
  extensions: [yamlLanguage()],
});
const sectionYSDC = EditorState.create({
  doc: `+thing:
  .type: +Str
.root:
  name: +Str
  age?: +Int
`,
  extensions: [yamlLanguage()],
});
const expectedSections = 'defs/thing,properties/name,properties/age';
for (const [state, format] of [
  [sectionJSON, 'json'],
  [sectionYSD, 'ysd'],
  [sectionYSDC, 'ysdc'],
]) {
  const sections = schemaSections(state, format)
    .map((section) => section.id).join(',');
  if (sections !== expectedSections) {
    throw new Error(`unexpected ${format} schema sections: ${sections}`);
  }
}

const sharedContent = '.title: Caf\u00e9 \ud83c\udf0d\nname: +Str\n';
const encodedContent = encodeContent(sharedContent);
if (decodeContent(encodedContent) !== sharedContent) {
  throw new Error('shared editor content did not survive compression');
}
const sharedHash = serializeEditorState({
  source: 'ysd',
  content: sharedContent,
  pane: 'ysd',
  lines: {anchor: 3, start: 3, end: 7},
});
if (!sharedHash.startsWith('#v=1&s=ysd&z=') ||
    !sharedHash.endsWith('&p=ysd&l=3-7')) {
  throw new Error(`shared editor URL is unstable: ${sharedHash}`);
}
const parsedShared = parseEditorState(sharedHash);
if (
  !parsedShared.ok ||
  parsedShared.state.source !== 'ysd' ||
  parsedShared.state.content !== sharedContent ||
  parsedShared.state.pane !== 'ysd' ||
  parsedShared.state.lines.start !== 3 ||
  parsedShared.state.lines.end !== 7
) {
  throw new Error(`shared editor URL did not parse: ${JSON.stringify(
    parsedShared,
  )}`);
}
const linesOnlyHash = serializeEditorState({
  pane: 'json',
  lines: {anchor: 8, start: 2, end: 8},
});
if (linesOnlyHash !== '#v=1&p=json&l=2-8') {
  throw new Error(`line-only editor URL is unstable: ${linesOnlyHash}`);
}
if (serializeEditorState({source: 'ysd'}) !== '') {
  throw new Error('canonical editor state produced a fragment');
}
for (const invalidHash of [
  '#v=2&s=ysd&z=x',
  '#v=1&s=ysd',
  '#v=1&s=ysd&z=not-gzip',
]) {
  if (parseEditorState(invalidHash).ok) {
    throw new Error(`invalid editor URL was accepted: ${invalidHash}`);
  }
}
const reversedLines = parseLineRange('8-2');
if (!reversedLines || reversedLines.anchor !== 8 ||
    reversedLines.start !== 2 || reversedLines.end !== 8) {
  throw new Error('reversed line range was not normalized');
}
const clampedLines = clampLineRange(reversedLines, 5);
if (!clampedLines || clampedLines.anchor !== 5 ||
    clampedLines.start !== 2 || clampedLines.end !== 5) {
  throw new Error('linked lines were not clamped to the document');
}
const extendedLines = nextLineRange(
  {anchor: 5, start: 5, end: 5},
  2,
  true,
);
if (extendedLines.anchor !== 5 || extendedLines.start !== 2 ||
    extendedLines.end !== 5) {
  throw new Error('shift-click did not extend from the linked-line anchor');
}

const unifiedDiff = globalThis.createUnifiedDiff;
const changedDiff = unifiedDiff('a\nb\nc', 'a\nx\nc');
const expectedChangedDiff = `--- original
+++ roundtrip
@@ -1,3 +1,3 @@
 a
-b
+x
 c
`;
if (changedDiff !== expectedChangedDiff) {
  throw new Error(`unexpected unified diff:\n${changedDiff}`);
}
if (unifiedDiff('same\n', 'same') !== '') {
  throw new Error('trailing newline produced a diff');
}
if (!unifiedDiff('', 'added').includes('@@ -0,0 +1 @@')) {
  throw new Error('empty-file insertion has the wrong range');
}
if (!unifiedDiff('removed', '').includes('@@ -1 +0,0 @@')) {
  throw new Error('empty-file deletion has the wrong range');
}

const separatedBefore = Array.from(
  {length: 12},
  (_, index) => `line ${index + 1}`,
);
const separatedAfter = [...separatedBefore];
separatedAfter[1] = 'changed 2';
separatedAfter[9] = 'changed 10';
const separatedDiff = unifiedDiff(
  separatedBefore.join('\n'),
  separatedAfter.join('\n'),
  1,
);
if ((separatedDiff.match(/^@@/gm) || []).length !== 2) {
  throw new Error(
    `separated changes did not form two hunks:\n${separatedDiff}`,
  );
}

const largeBefore = Array.from(
  {length: 2000},
  (_, index) => `large line ${index + 1}`,
);
const largeAfter = [...largeBefore];
largeAfter[1000] = 'large changed line';
if (!unifiedDiff(
  largeBefore.join('\n'),
  largeAfter.join('\n'),
).includes('+large changed line')) {
  throw new Error('large unified diff omitted its changed line');
}

const trailing = normalizeJson('{"a": [1, 2,],}');
if (JSON.stringify(JSON.parse(trailing)) !== '{"a":[1,2]}') {
  throw new Error('trailing JSON commas were not normalized');
}

if (normalizeJson('{"text": ",}"}') !== '{"text": ",}"}') {
  throw new Error('a comma inside a JSON string was changed');
}

for (const invalidJSON of [
  '{"title": not valid json}',
  '{"a": 1 "b": 2}',
]) {
  try {
    normalizeJson(invalidJSON);
    throw new Error(`invalid JSON was accepted: ${invalidJSON}`);
  } catch (error) {
    if (error.message.startsWith('invalid JSON was accepted')) throw error;
  }
}

const go = new Go();
const bytes = await readFile('docs/assets/editor/ysd.wasm');
const {instance} = await WebAssembly.instantiate(bytes, go.importObject);
go.run(instance);

for (let attempt = 0; attempt < 200 && !globalThis.gloat; attempt += 1) {
  await new Promise((resolve) => setTimeout(resolve, 10));
}

if (!globalThis.gloat) throw new Error('gloat export object was not installed');

const normalizedResult = globalThis.gloat.exports[
  'json-schema-normalize'
]('{"type":"object","additionalProperties":true}');
if (!normalizedResult.ok) {
  throw new Error(`JSON normalization failed: ${JSON.stringify(
    normalizedResult,
  )}`);
}
const normalizedSchema = JSON.parse(normalizedResult.value);
if (
  normalizedSchema.$schema !==
    'https://json-schema.org/draft/2020-12/schema' ||
  normalizedSchema.type !== 'object' ||
  Object.hasOwn(normalizedSchema, 'additionalProperties')
) {
  throw new Error(`unexpected normalized JSON: ${normalizedResult.value}`);
}

const blogText = await readFile(
  'docs/assets/editor/examples/blog-post.schema.json',
  'utf8',
);
const normalizedBlogResult = globalThis.gloat.exports[
  'json-schema-normalize'
](blogText);
const normalizedBlog = normalizedBlogResult.ok
  ? JSON.parse(normalizedBlogResult.value)
  : {};
if (
  !normalizedBlogResult.ok ||
  Object.keys(normalizedBlog.properties).join(',') !==
    'title,content,publishedDate,author,tags' ||
  normalizedBlog.required.join(',') !== 'title,content,author'
) {
  throw new Error(`normalization reordered Blog Post: ${JSON.stringify(
    normalizedBlogResult,
  )}`);
}

const orderedNames = [
  'zebra',
  'alpha',
  'yankee',
  'bravo',
  'xray',
  'charlie',
  'whiskey',
  'delta',
  'victor',
  'echo',
];
const orderedProperties = Object.fromEntries(
  orderedNames.map((name) => [name, {type: 'string'}]),
);
const orderedJSON = JSON.stringify({
  type: 'object',
  properties: orderedProperties,
});
const orderedNormalizeResult = globalThis.gloat.exports[
  'json-schema-normalize'
](orderedJSON);
const orderedNormalized = orderedNormalizeResult.ok
  ? JSON.parse(orderedNormalizeResult.value)
  : {};
if (
  !orderedNormalizeResult.ok ||
  Object.keys(orderedNormalized.properties).join(',') !==
    orderedNames.join(',')
) {
  throw new Error(`normalization reordered properties: ${JSON.stringify(
    orderedNormalizeResult,
  )}`);
}

const orderedYSD = orderedNames.map((name) => `${name}: +Str`).join('\n');
const orderedConversionResult = globalThis.gloat.exports[
  'ysd-to-json-schema'
](orderedYSD);
const orderedConverted = orderedConversionResult.ok
  ? JSON.parse(orderedConversionResult.value)
  : {};
if (
  !orderedConversionResult.ok ||
  Object.keys(orderedConverted.properties).join(',') !==
    orderedNames.join(',')
) {
  throw new Error(`YSD conversion reordered properties: ${JSON.stringify(
    orderedConversionResult,
  )}`);
}

const appSource = await readFile('src/editor/app.js', 'utf8');
if (
  !appSource.includes(
    "jsonSchemaTitle.addEventListener('dblclick', clearSiteCookies)",
  ) ||
  !appSource.includes('document.cookie =') ||
  !appSource.includes('Max-Age=0') ||
  !appSource.includes("window.location.assign('https://yamlschema.org/demo/')")
) {
  throw new Error('JSON Schema cookie-clearing shortcut is missing');
}
if (
  !appSource.includes('sampleRouteSelected = Boolean(requestedSample)') ||
  !appSource.includes(
    'sampleRouteSelected ? selectedSample : undefined',
  )
) {
  throw new Error('base demo route does not wait for a schema selection');
}
const codeEditorSource = await readFile('src/editor/editor.js', 'utf8');
const bundledApp = await readFile('docs/assets/editor/app.js', 'utf8');
const styleSource = await readFile(
  'docs/assets/editor/editor.css',
  'utf8',
);
if (bundledApp.length < 100000 ||
    /(?:from|import)\s*[(']["']@codemirror\//.test(bundledApp)) {
  throw new Error('CodeMirror browser bundle was not built locally');
}
if (appSource.includes('globalThis.gloat')) {
  throw new Error('the browser app calls Wasm on the UI thread');
}
for (const worker of ['schema-worker.js', 'roundtrip-worker.js']) {
  if (!appSource.includes(`new URL('./${worker}', import.meta.url)`)) {
    throw new Error(`${worker} is not used by the browser app`);
  }
}
if (!appSource.includes('roundtripWorker.terminate()')) {
  throw new Error('stale roundtrip work is not cancelled');
}
if (!appSource.includes('roundtripDiffDialog.showModal()')) {
  throw new Error('roundtrip diff modal is not opened by the browser app');
}
if (
  !appSource.includes("updateRoundtripStatus('json', json)") ||
  !appSource.includes("updateRoundtripStatus('ysd', ysd)")
) {
  throw new Error('roundtrip direction does not follow the edited pane');
}
if (
  !appSource.includes('onFocus: () => editorFocused(jsonEditor)') ||
  !appSource.includes('onFocus: () => editorFocused(yamlEditor)') ||
  !appSource.includes(
    "const source = editor === jsonEditor ? 'json' : 'ysd'",
  ) ||
  !appSource.includes('delete canonicalSourceValues[source]') ||
  !appSource.includes('scheduleEditorURL();') ||
  !appSource.includes('roundtripOnFocus(editor)') ||
  !appSource.includes("updateRoundtripStatus('json', json, 0)") ||
  !appSource.includes("updateRoundtripStatus('ysd', yamlEditor.value, 0)")
) {
  throw new Error('focusing an editor does not start its roundtrip check');
}
for (const feature of [
  'lineNumbers({',
  'foldGutter()',
  'bracketMatching()',
  'EditorView.lineWrapping',
  'setReadOnly(readOnly)',
  'setLinkedLines(range, scroll = false)',
  'scrollToLinkedLines(range)',
  "EditorView.scrollIntoView(position, {y: 'start'})",
  'schemaLocation(format)',
  'scrollToSchemaLocation(location, format)',
  "this.view.scrollDOM.addEventListener('scroll'",
]) {
  if (!codeEditorSource.includes(feature)) {
    throw new Error(`CodeMirror editor is missing: ${feature}`);
  }
}
if (
  !appSource.includes('parseEditorState(window.location.hash)') ||
  !appSource.includes('serializeEditorState({') ||
  !appSource.includes('Custom from ${origin}') ||
  !appSource.includes(
    'replaceEditorURL(sampleRouteSelected ? selectedSample : ' +
    'undefined, hash)',
  )
) {
  throw new Error('shareable editor URL state is incomplete');
}
if (
  !appSource.includes('if (sharedState.content !== undefined)') ||
  !appSource.includes('canonicalSourceValues = {};') ||
  !appSource.includes('} else {\n    await loadSelectedSample(')
) {
  throw new Error('shared content does not bypass initial sample conversion');
}
if (
  !appSource.includes("setEditorValue(yamlEditor, 'Generating YSDC...')") ||
  !appSource.includes("yamlFormat === 'ysdc' ? 'YSDC' : 'YSD'") ||
  !appSource.includes('showGeneratingYamlSchema();') ||
  !appSource.includes('const conversion = convertYamlToJson();') ||
  !appSource.includes('showGeneratingYSDC();')
) {
  throw new Error('old YAML remains visible while YSD or YSDC is generated');
}
if (
  !appSource.includes(
    "setEditorValue(jsonEditor, 'Generating JSON Schema...')",
  ) ||
  !appSource.includes('showGeneratingJSONSchema();')
) {
  throw new Error('old JSON remains visible while JSON is being generated');
}
if (
  !appSource.includes(
    "roundtripDiffDialog.addEventListener('click', closeDiffFromBackdrop)",
  ) ||
  !appSource.includes('roundtripDiffDialog.getBoundingClientRect()')
) {
  throw new Error('roundtrip diff does not close from its backdrop');
}
if (
  !appSource.includes('editorHelpDialog.showModal()') ||
  !appSource.includes(
    "editorHelpDialog.addEventListener('click', closeHelpFromBackdrop)",
  ) ||
  !appSource.includes('editorHelpDialog.getBoundingClientRect()')
) {
  throw new Error('editor help dialog behavior is incomplete');
}
if (
  !appSource.includes('editorSettingsDialog.showModal()') ||
  !appSource.includes('yamlschema.scroll-sync') ||
  !appSource.includes('editor !== scrollSyncSourceEditor()') ||
  !appSource.includes('scrollToSchemaLocation') ||
  !appSource.includes('requestAnimationFrame')
) {
  throw new Error('editor settings or scroll synchronization is incomplete');
}
if (
  !appSource.includes('navigator.share({title: \'YAMLSchema\', url})') ||
  !appSource.includes('navigator.clipboard?.writeText') ||
  !appSource.includes("setShareStatus('Link copied')")
) {
  throw new Error('editor sharing behavior is incomplete');
}
if (
  !appSource.includes('setRoundtripSource(side)') ||
  !appSource.includes('indicator.dataset.roundtripSource')
) {
  throw new Error('roundtrip status does not follow the source pane');
}
if (
  !appSource.includes("person: {url: assetURL('examples/person.ysd.yaml')}") ||
  !appSource.includes("'harbor-next': {url: assetURL('values.ysd.yaml')}") ||
  !appSource.includes("if (side === 'json') await showJsonSample(content)") ||
  !appSource.includes('else await showSample(content)')
) {
  throw new Error('packaged examples do not convert from their own side');
}
if (
  !appSource.includes("ysd: 'yamlschema.sample.ysd'") ||
  !appSource.includes("json: 'yamlschema.sample.json'") ||
  !appSource.includes('yamlschema.sample-source')
) {
  throw new Error('example selector choices are not persistent');
}
if (
  !appSource.includes("if (current !== side) other.value = ''") ||
  !appSource.includes('selectSampleSource(initialSampleSource,')
) {
  throw new Error('inactive example selector is not cleared');
}
if (
  !appSource.includes('schemaEditor.dataset.schemaSlug') ||
  !appSource.includes('window.history.replaceState') ||
  !appSource.includes(
    'replaceEditorURL(\n  sampleRouteSelected ? initialSample : undefined,',
  )
) {
  throw new Error('editor schema routes do not select canonical inputs');
}
if (
  !appSource.includes("callWorker('json-schema-normalize', json)") ||
  !appSource.includes('await convertJsonToYaml()')
) {
  throw new Error('Normalize does not run conversion and roundtrip');
}
if (
  !styleSource.includes('.roundtrip-status:not(.source-active)') ||
  !styleSource.includes('visibility: hidden')
) {
  throw new Error('inactive roundtrip status is not hidden');
}
if (!styleSource.includes('font-weight: 900')) {
  throw new Error('roundtrip status indicator is not strongly weighted');
}
if (
  !styleSource.includes('@media (max-width: 900px) and ' +
    '(orientation: portrait)') ||
  !styleSource.includes('height: calc(100dvh - 3.6rem)') ||
  !styleSource.includes('grid-template-rows: repeat(2, minmax(0, 1fr))') ||
  !styleSource.includes('body:has(.schema-editor) .md-footer') ||
  !styleSource.includes('.schema-editor .error:empty')
) {
  throw new Error('both editor panes do not fit in the portrait layout');
}
const roundtripWorkerSource = await readFile(
  'docs/assets/editor/roundtrip-worker.js',
  'utf8',
);
if (
  !roundtripWorkerSource.includes("importScripts('unified-diff.js?v=1')") ||
  !roundtripWorkerSource.includes("'json-schema-roundtrip-report'") ||
  !roundtripWorkerSource.includes("'ysd-roundtrip-report'")
) {
  throw new Error('roundtrip worker does not generate browser diffs');
}

const pastedYSD = await readFile('test/ansible-builder.ysd.yaml', 'utf8');
const pastedResult = globalThis.gloat.exports['ysd-to-json-schema'](
  pastedYSD,
);
if (!pastedResult.ok) {
  throw new Error(`pasted YSD conversion failed: ${JSON.stringify(
    pastedResult,
  )}`);
}
const pastedRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](pastedYSD);
if (!pastedRoundtrip.ok || pastedRoundtrip.value !== true) {
  throw new Error(`unexpected pasted YSD roundtrip: ${JSON.stringify(
    pastedRoundtrip,
  )}`);
}

const ansibleBuilderJSON = await readFile(
  'docs/assets/editor/examples/ansible-builder.schema.json',
  'utf8',
);
const ansibleBuilderYSD = globalThis.gloat.exports[
  'json-schema-to-ysd'
](ansibleBuilderJSON);
const ansibleBuilderRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](ansibleBuilderJSON);
if (
  !ansibleBuilderYSD.ok ||
  !ansibleBuilderYSD.value.includes('python?: +Str[$]') ||
  !ansibleBuilderYSD.value.includes('system?: +Str[$]') ||
  !ansibleBuilderYSD.value.includes('package_pip: +Str') ||
  !ansibleBuilderRoundtrip.ok ||
  ansibleBuilderRoundtrip.value !== true
) {
  throw new Error(`Ansible Builder conversion failed: ${JSON.stringify({
    conversion: ansibleBuilderYSD,
    roundtrip: ansibleBuilderRoundtrip,
  })}`);
}

const netboxJSON = await readFile(
  'docs/assets/editor/examples/netbox-generated.schema.json',
  'utf8',
);
const netboxYSD = globalThis.gloat.exports[
  'json-schema-to-ysd'
](netboxJSON);
const netboxRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](netboxJSON);
if (
  !netboxYSD.ok ||
  !netboxYSD.value.includes('.root: {}') ||
  !netboxRoundtrip.ok ||
  netboxRoundtrip.value !== true
) {
  throw new Error(`NetBox conversion failed: ${JSON.stringify({
    conversion: netboxYSD,
    roundtrip: netboxRoundtrip,
  })}`);
}

const exampleFiles = [
  'address',
  'blog-post',
  'calendar',
  'device-type',
  'ecommerce-system',
  'geographical-location',
  'health-record',
  'job-posting',
  'movie',
  'user-profile',
  'ansible-builder',
  'netbox-generated',
];
const routedExamples = [
  ['person', 'ysd'],
  ['harbor-next', 'ysd'],
  ...exampleFiles.map((name) => [name, 'json']),
];
const indexHTML = await readFile('site/demo/index.html', 'utf8');
const mkdocsConfig = await readFile('mkdocs.yaml', 'utf8');
if (
  mkdocsConfig.includes('- YAMLSchema:') ||
  !mkdocsConfig.includes('- Demo: demo/index.md')
) {
  throw new Error('site navigation has an incorrect home or demo tab');
}
if (
  !indexHTML.includes('<a href=".." title="YAMLSchema"') ||
  !indexHTML.includes('<a href=".." class="md-header__title"') ||
  !indexHTML.includes('aria-label="YAMLSchema home"')
) {
  throw new Error('header icon and title do not link to the home page');
}
if (
  !indexHTML.includes('id="normalize-json"') ||
  !indexHTML.includes('id="json-schema-title"') ||
  !indexHTML.includes('id="editor-settings-open"') ||
  !indexHTML.includes('aria-label="Open editor settings"') ||
  !indexHTML.includes('class="editor-actions"') ||
  !indexHTML.includes('id="editor-share"') ||
  !indexHTML.includes('aria-label="Share editor link"') ||
  indexHTML.includes('data-schema-slug=')
) {
  throw new Error('base demo page has incorrect editor controls or routing');
}
if (
  indexHTML.includes('<textarea') ||
  !indexHTML.includes('id="yaml-schema" class="code-editor"') ||
  !indexHTML.includes('id="json-schema" class="code-editor"')
) {
  throw new Error('editor panes are not CodeMirror mount points');
}
if (
  indexHTML.includes('data-md-component="sidebar"') ||
  !styleSource.includes(
    'body:has(.schema-editor) .md-main__inner',
  )
) {
  throw new Error('editor does not use the full page width');
}
if (
  !indexHTML.includes('id="editor-help-open"') ||
  !indexHTML.includes('href="#editor-help-dialog"') ||
  !indexHTML.includes('aria-haspopup="dialog"') ||
  !indexHTML.includes('title="Open editor help">YAMLSchema</a>')
) {
  throw new Error('YAMLSchema editor heading is incorrect');
}
if (
  !indexHTML.includes('id="editor-help-dialog"') ||
  !indexHTML.includes('This editor converts between YAMLSchema') ||
  !indexHTML.includes('back without losing information') ||
  !indexHTML.includes('a diff is available to show') ||
  !indexHTML.includes('Choose a starting schema') ||
  !indexHTML.includes('Understand roundtrip status') ||
  !indexHTML.includes('Normalize JSON Schema') ||
  !indexHTML.includes('Share content and lines')
) {
  throw new Error('editor help instructions are incomplete');
}
if (!indexHTML.includes(
  'Opening the shared link scrolls the selected range to the top of',
)) {
  throw new Error('shared line links do not document automatic scrolling');
}
if (
  !indexHTML.includes('id="editor-settings-dialog"') ||
  !indexHTML.includes('id="scroll-sync" checked') ||
  !indexHTML.includes('<strong>Scroll sync</strong>') ||
  !styleSource.includes('.schema-editor #editor-settings-dialog')
) {
  throw new Error('editor settings dialog is incomplete');
}
if (
  !styleSource.includes('.cm-linked-line') ||
  !styleSource.includes('.cm-linked-line-number') ||
  !styleSource.includes('.code-editor:focus-within')
) {
  throw new Error('CodeMirror linked-line styling is incomplete');
}
if (
  !styleSource.includes('.schema-editor .editor-help-link::after') ||
  !styleSource.includes('color: var(--md-typeset-a-color)') ||
  !styleSource.includes('.schema-editor .editor-help-link:focus-visible')
) {
  throw new Error('YAMLSchema help link is not styled as a link');
}
if (
  indexHTML.includes('<h1>Interactive editor</h1>') ||
  indexHTML.includes('Edit either schema and the other side updates')
) {
  throw new Error('editor introduction is still visible');
}
if (!styleSource.includes('margin-top: 0;')) {
  throw new Error('editor top spacing is not compact');
}
for (const source of ['ysd', 'json']) {
  if (!indexHTML.includes(`data-roundtrip-source="${source}"`)) {
    throw new Error(`${source} roundtrip status source is missing`);
  }
}
if (indexHTML.includes('<optgroup')) {
  throw new Error('example selectors are not flat');
}
const yamlSelectHTML = indexHTML.match(
  /<select id="yaml-sample-select"[\s\S]*?<\/select>/,
)?.[0] || '';
const jsonSelectHTML = indexHTML.match(
  /<select id="json-sample-select"[\s\S]*?<\/select>/,
)?.[0] || '';
for (const selectHTML of [yamlSelectHTML, jsonSelectHTML]) {
  if (!selectHTML.includes(
    '<option value="" disabled selected>Choose a schema</option>',
  )) {
    throw new Error('example selector placeholder is missing');
  }
}
for (const name of ['person', 'harbor-next']) {
  if (!yamlSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is missing from the YAMLSchema selector`);
  }
  if (jsonSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is incorrectly in the JSON Schema selector`);
  }
}
if (yamlSelectHTML.indexOf('value="person"') >
    yamlSelectHTML.indexOf('value="harbor-next"')) {
  throw new Error('YAMLSchema example order is wrong');
}
if (jsonSelectHTML.indexOf('value="netbox-generated"') <
    jsonSelectHTML.indexOf('value="ansible-builder"')) {
  throw new Error('NetBox Generated is not the last JSON Schema example');
}
if (
  !indexHTML.includes('id="roundtrip-diff-dialog"') ||
  !indexHTML.includes('id="roundtrip-diff"')
) {
  throw new Error('roundtrip diff dialog is missing');
}
for (const [slug] of routedExamples) {
  const routeHTML = await readFile(`site/demo/${slug}/index.html`, 'utf8');
  if (!routeHTML.includes(`data-schema-slug="${slug}"`)) {
    throw new Error(`${slug} editor route has the wrong schema slug`);
  }
  if (!routeHTML.includes('id="yaml-schema"') ||
      !routeHTML.includes('id="json-schema"')) {
    throw new Error(`${slug} editor route is missing the shared editor`);
  }
}
let oldEditorExists = true;
try {
  await readFile('site/edit/index.html');
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  oldEditorExists = false;
}
if (oldEditorExists) {
  throw new Error('old editor route was generated');
}

const homeHTML = await readFile('site/index.html', 'utf8');
if (!homeHTML.includes('Define a lot more')) {
  throw new Error('home page tagline is missing');
}
if (
  !homeHTML.includes('class="home-proof" data-editor-href="demo/person/"') ||
  !homeHTML.includes('aria-label="Open Person in the demo"')
) {
  throw new Error('home proof card does not open the Person demo');
}
if ((homeHTML.match(/data-comparison-slide/g) || []).length !== 3) {
  throw new Error('home page comparison carousel is incomplete');
}
for (const href of [
  'demo/person/',
  'demo/address/',
  'demo/device-type/',
]) {
  if (!homeHTML.includes(href)) {
    throw new Error(`home page editor link is missing: ${href}`);
  }
}
const carouselSource = await readFile(
  'docs/javascripts/carousel.js',
  'utf8',
);
if (
  !carouselSource.includes(
    "'[data-editor-href]:not([data-comparison-slide])'",
  ) ||
  !carouselSource.includes('window.setInterval') ||
  !carouselSource.includes('prefers-reduced-motion') ||
  !carouselSource.includes('7000')
) {
  throw new Error('comparison carousel behavior is incomplete');
}
const cheatHTML = await readFile('site/cheat-sheet/index.html', 'utf8');
if (!cheatHTML.includes('cheat-grid') || !cheatHTML.includes('Built-in types')) {
  throw new Error('cheat sheet was not built');
}
const cname = await readFile('site/CNAME', 'utf8');
if (cname.trim() !== 'yamlschema.org') {
  throw new Error(`unexpected CNAME: ${cname}`);
}
for (const endpoint of ['install', 'install.mk']) {
  const source = await readFile(`docs/${endpoint}`, 'utf8');
  const built = await readFile(`site/${endpoint}`, 'utf8');
  if (built !== source) {
    throw new Error(`${endpoint} was not copied unchanged`);
  }
}
const homeSource = await readFile('docs/index.md', 'utf8');
if (
  !homeSource.includes('source <(curl -sL yamlschema.org/install)') ||
  !homeSource.includes('curl -sL yamlschema.org/install | source -') ||
  !homeSource.includes(
    'enables tab completion and the YAMLSchema man pages',
  ) ||
  !homeHTML.includes('yamlschema.org/install')
) {
  throw new Error('home page quick-install commands are missing');
}
const gettingStartedSource = await readFile(
  'docs/getting-started.md',
  'utf8',
);
if (
  !gettingStartedSource.includes('immediately enables tab completion') ||
  !gettingStartedSource.includes('Try `ysd --<TAB>` or `man ysd`')
) {
  throw new Error('installation shell features are not documented');
}
for (const name of exampleFiles) {
  if (!jsonSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is missing from the JSON Schema selector`);
  }
  if (yamlSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is incorrectly in the YAMLSchema selector`);
  }
  const text = await readFile(
    `docs/assets/editor/examples/${name}.schema.json`,
    'utf8',
  );
  const schema = JSON.parse(text);
  if (schema.$schema &&
      schema.$schema !== 'https://json-schema.org/draft/2020-12/schema') {
    throw new Error(`${name} does not use JSON Schema 2020-12`);
  }
  const converted = globalThis.gloat.exports['json-schema-to-ysd'](text);
  if (!converted.ok) {
    throw new Error(`${name} conversion failed: ${JSON.stringify(
      converted,
    )}`);
  }
  const roundtrip = globalThis.gloat.exports[
    'json-schema-roundtrip-works'
  ](text);
  if (!roundtrip.ok || typeof roundtrip.value !== 'boolean') {
    throw new Error(`${name} roundtrip check failed: ${JSON.stringify(
      roundtrip,
    )}`);
  }
  if (name === 'address') {
    if (roundtrip.value !== true) {
      const report = globalThis.gloat.exports[
        'json-schema-roundtrip-report'
      ](text);
      throw new Error(`address did not roundtrip: ${JSON.stringify(
        {roundtrip, report},
      )}`);
    }
    if (!converted.value.includes(':need(streetAddress)')) {
      throw new Error('address dependencies are missing from YSD');
    }
  }
  if (name === 'blog-post') {
    if (roundtrip.value !== true) {
      throw new Error(`blog-post did not roundtrip: ${JSON.stringify(
        roundtrip,
      )}`);
    }
    if (
      !converted.value.includes(
        'author: +Ref(https://example.com/user-profile.schema.json)',
      )
    ) {
      throw new Error('blog-post external author reference is missing');
    }
  }
  if (name === 'device-type') {
    if (roundtrip.value !== true) {
      throw new Error(`device-type did not roundtrip: ${JSON.stringify(
        roundtrip,
      )}`);
    }
    for (const expected of [
      '.one:',
      '.xref: https://example.com/smartphone.schema.json',
      'deviceType?: +Str ==smartphone',
      '.xref: https://example.com/laptop.schema.json',
      'deviceType?: +Str ==laptop',
    ]) {
      if (!converted.value.includes(expected)) {
        throw new Error(`device-type YSD is missing: ${expected}`);
      }
    }
  }
}

const initialYSD = await readFile(
  'docs/assets/editor/examples/person.ysd.yaml',
  'utf8',
);
const expectedInitialYSD = `name: +Str
age?: +Int 0..120
email?: +JSONSchema/email
tags?: +Str[] [=good, bad, ugly]
`;
if (initialYSD !== expectedInitialYSD) {
  throw new Error(`unexpected Person YSD: ${initialYSD}`);
}
const initialResult = globalThis.gloat.exports['ysd-to-json-schema'](
  initialYSD,
);
if (!initialResult.ok) {
  throw new Error(`initial YSD conversion failed: ${JSON.stringify(
    initialResult,
  )}`);
}
const initialJSON = JSON.parse(initialResult.value);
if (
  initialJSON.$schema !==
    'https://json-schema.org/draft/2020-12/schema' ||
  initialJSON.title !== undefined ||
  initialJSON.type !== 'object' ||
  initialJSON.additionalProperties !== false ||
  initialJSON.required.join(',') !== 'name' ||
  Object.keys(initialJSON.properties).join(',') !== 'name,age,email,tags' ||
  initialJSON.properties.name.type !== 'string' ||
  initialJSON.properties.email.format !== 'email' ||
  initialJSON.properties.age.type !== 'integer' ||
  initialJSON.properties.age.minimum !== 0 ||
  initialJSON.properties.age.maximum !== 120 ||
  initialJSON.properties.tags.type !== 'array' ||
  initialJSON.properties.tags.default !== 'good' ||
  initialJSON.properties.tags.items.enum.join(',') !== 'good,bad,ugly'
) {
  throw new Error(`unexpected initial JSON: ${initialResult.value}`);
}
const initialBackToYSD = globalThis.gloat.exports['json-schema-to-ysd'](
  initialResult.value,
);
if (
  !initialBackToYSD.ok ||
  !initialBackToYSD.value.includes(
    'tags?: +Str[] [=good, bad, ugly]',
  )
) {
  throw new Error(`unexpected regenerated Person YSD: ${JSON.stringify(
    initialBackToYSD,
  )}`);
}
const initialRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](initialYSD);
if (!initialRoundtrip.ok || initialRoundtrip.value !== true) {
  throw new Error(`unexpected initial roundtrip: ${JSON.stringify(
    initialRoundtrip,
  )}`);
}

const formatResult = globalThis.gloat.exports['ysd-to-json-schema'](
  'dateOfBirth: +JSONSchema/date',
);
const formatJSON = formatResult.ok ? JSON.parse(formatResult.value) : {};
if (
  !formatResult.ok ||
  formatJSON.properties?.dateOfBirth?.type !== 'string' ||
  formatJSON.properties?.dateOfBirth?.format !== 'date'
) {
  throw new Error(`qualified format conversion failed: ${JSON.stringify(
    formatResult,
  )}`);
}

const harborYSD = await readFile(
  'docs/assets/editor/values.ysd.yaml',
  'utf8',
);
const harborResult = globalThis.gloat.exports['ysd-to-json-schema'](
  harborYSD,
);
if (!harborResult.ok) {
  throw new Error(`Harbor Next sample failed: ${JSON.stringify(
    harborResult,
  )}`);
}
const harborJSON = JSON.parse(harborResult.value);
if (harborJSON.title !== 'Harbor Next Helm Chart Values') {
  throw new Error(`unexpected Harbor Next title: ${harborJSON.title}`);
}
const harborYSDC = globalThis.gloat.exports['json-schema-to-ysdc'](
  harborResult.value,
);
if (
  !harborYSDC.ok ||
  !harborYSDC.value.includes('.range: [1, 100]')
) {
  throw new Error(`Harbor Next YSDC ranges are not compact: ${JSON.stringify(
    harborYSDC,
  )}`);
}
const harborKeys = Object.keys(harborJSON).slice(0, 6).join(',');
const expectedHarborKeys = '$id,$schema,title,description,$defs,type';
if (harborKeys !== expectedHarborKeys) {
  throw new Error(`unexpected Harbor Next key order: ${harborKeys}`);
}
const harborRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](harborYSD);
if (!harborRoundtrip.ok || harborRoundtrip.value !== true) {
  const reportResult = globalThis.gloat.exports[
    'ysd-roundtrip-report'
  ](harborYSD);
  const report = reportResult.ok ? JSON.parse(reportResult.value) : {};
  const diff = unifiedDiff(report.original || '', report.roundtripped || '')
    .split('\n').slice(0, 50).join('\n');
  throw new Error(`unexpected Harbor Next roundtrip: ${JSON.stringify({
    harborRoundtrip,
    propertyKeys: Object.keys(harborJSON.properties || {}).slice(0, 20),
    diff,
  })}`);
}

const json = JSON.stringify({
  $id: 'https://example.com/person.schema.json',
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  required: ['name'],
  properties: {name: {type: 'string'}},
});
const toYSD = globalThis.gloat.exports['json-schema-to-ysd'](json);
if (!toYSD.ok ||
    !toYSD.value.startsWith(
      '# Converted from JSON Schema\n' +
      '.ysid: https://example.com/person.ysd.yaml\n',
    ) ||
    !toYSD.value.includes('name:')) {
  throw new Error(`JSON to YSD failed: ${JSON.stringify(toYSD)}`);
}

const toJSON = globalThis.gloat.exports['ysd-to-json-schema'](toYSD.value);
if (!toJSON.ok ||
    JSON.parse(toJSON.value).$id !==
      'https://example.com/person.schema.json' ||
    JSON.parse(toJSON.value).type !== 'object') {
  throw new Error(`YSD to JSON failed: ${JSON.stringify(toJSON)}`);
}

const toYSDC = globalThis.gloat.exports['json-schema-to-ysdc'](json);
const expectedYSDC =
  '.ysid: https://example.com/person.ysd.yaml\n' +
  '.open: true\nname: +Str';
if (!toYSDC.ok || toYSDC.value !== expectedYSDC) {
  throw new Error(`JSON to YSDC failed: ${JSON.stringify(toYSDC)}`);
}

const closedYSDC = globalThis.gloat.exports[
  'json-schema-to-ysdc'
](initialResult.value);
if (!closedYSDC.ok || closedYSDC.value.includes('.open: true')) {
  throw new Error(`closed JSON produced open YSDC: ${JSON.stringify(
    closedYSDC,
  )}`);
}

const lossyJSON = JSON.stringify({minimum: 1});

const failedRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](lossyJSON);
if (!failedRoundtrip.ok || failedRoundtrip.value !== false) {
  throw new Error(`expected roundtrip failure: ${JSON.stringify(
    failedRoundtrip,
  )}`);
}
const failedReportResult = globalThis.gloat.exports[
  'json-schema-roundtrip-report'
](lossyJSON);
if (!failedReportResult.ok) {
  throw new Error(`roundtrip report failed: ${JSON.stringify(
    failedReportResult,
  )}`);
}
const failedReport = JSON.parse(failedReportResult.value);
if (
  failedReport.works !== false ||
  typeof failedReport.original !== 'string' ||
  typeof failedReport.roundtripped !== 'string' ||
  !unifiedDiff(
    failedReport.original,
    failedReport.roundtripped,
  ).startsWith('--- original\n+++ roundtrip\n')
) {
  throw new Error(`invalid failed roundtrip report: ${JSON.stringify(
    failedReport,
  )}`);
}

const closed = JSON.stringify({
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  properties: {name: {type: 'string'}},
  additionalProperties: false,
});
const workingRoundtrip = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](closed);
if (!workingRoundtrip.ok || workingRoundtrip.value !== true) {
  throw new Error(`expected working roundtrip: ${JSON.stringify(
    workingRoundtrip,
  )}`);
}
const workingReportResult = globalThis.gloat.exports[
  'json-schema-roundtrip-report'
](closed);
const workingReport = workingReportResult.ok
  ? JSON.parse(workingReportResult.value)
  : {};
if (
  !workingReportResult.ok ||
  workingReport.works !== true ||
  unifiedDiff(workingReport.original, workingReport.roundtripped) !== ''
) {
  throw new Error(`invalid working roundtrip report: ${JSON.stringify(
    workingReportResult,
  )}`);
}

const invalid = globalThis.gloat.exports['json-schema-to-ysd']('{');
if (invalid.ok || !invalid.error) {
  throw new Error('invalid JSON did not return an error envelope');
}
const invalidReport = globalThis.gloat.exports[
  'json-schema-roundtrip-report'
]('{');
if (invalidReport.ok || !invalidReport.error) {
  throw new Error('invalid JSON did not fail roundtrip reporting');
}

const lossyYSD = `.open: true
value: +Float 0..`;
const failedYSDRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](lossyYSD);
if (!failedYSDRoundtrip.ok || failedYSDRoundtrip.value !== false) {
  throw new Error(`expected YSD roundtrip failure: ${JSON.stringify(
    failedYSDRoundtrip,
  )}`);
}
const failedYSDReportResult = globalThis.gloat.exports[
  'ysd-roundtrip-report'
](lossyYSD);
const failedYSDReport = failedYSDReportResult.ok
  ? JSON.parse(failedYSDReportResult.value)
  : {};
if (
  !failedYSDReportResult.ok ||
  failedYSDReport.works !== false ||
  !unifiedDiff(
    failedYSDReport.original,
    failedYSDReport.roundtripped,
  ).includes('-  .type: +Float\n+  .type: +Num')
) {
  throw new Error(`invalid YSD roundtrip report: ${JSON.stringify(
    failedYSDReportResult,
  )}`);
}

for (const invalidYSD of ['bad: [', '.unknown: true', 'name: +Stx']) {
  const result = globalThis.gloat.exports['ysd-to-json-schema'](invalidYSD);
  if (result.ok || !result.error) {
    throw new Error(`invalid YSD did not return an error: ${invalidYSD}`);
  }
  const report = globalThis.gloat.exports['ysd-roundtrip-report'](
    invalidYSD,
  );
  if (report.ok || !report.error) {
    throw new Error(`invalid YSD roundtrip did not fail: ${invalidYSD}`);
  }
}

console.log('browser exports converted YSD, YSDC, and JSON');
process.exit(0);
