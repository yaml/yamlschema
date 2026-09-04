import '../docs/assets/editor/wasm_exec.js';
import {json as jsonLanguage} from '@codemirror/lang-json';
import {yaml as yamlLanguage} from '@codemirror/lang-yaml';
import {EditorState} from '@codemirror/state';
import {readFile} from 'node:fs/promises';
import {
  normalizeJson,
  prepareJsonSchemaInput,
} from '../docs/assets/editor/json.js';
import {ResultCache, resultCacheKey} from '../src/editor/result-cache.js';
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

const resultCache = new ResultCache(2);
const firstCacheKey = resultCacheKey('convert', 'first');
const secondCacheKey = resultCacheKey('convert', 'second');
const thirdCacheKey = resultCacheKey('convert', 'third');
resultCache.set(firstCacheKey, 'one');
resultCache.set(secondCacheKey, 'two');
if (resultCache.get(firstCacheKey) !== 'one') {
  throw new Error('generated result cache did not return its value');
}
resultCache.set(thirdCacheKey, 'three');
if (resultCache.get(secondCacheKey) !== undefined ||
    resultCache.get(thirdCacheKey) !== 'three') {
  throw new Error('generated result cache did not evict the least recent');
}
resultCache.clear();
if (resultCache.get(firstCacheKey) !== undefined) {
  throw new Error('generated result cache did not clear its values');
}
if (resultCacheKey('ab', 'c') === resultCacheKey('a', 'bc')) {
  throw new Error('generated result cache keys are ambiguous');
}

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
const sectionLegacyJSON = EditorState.create({
  doc: `{
  "definitions": {"thing": {"type": "string"}},
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  }
}`,
  extensions: [jsonLanguage()],
});
const sectionYamlJSC = EditorState.create({
  doc: `$defs:
  thing:
    type: string
type: object
properties:
  name:
    type: string
  age:
    type: integer
`,
  extensions: [yamlLanguage()],
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
const sectionJSONYSDC = EditorState.create({
  doc: `{
  "+thing": {".type": "+Str"},
  ".root": {
    "name": "+Str",
    "age?": "+Int"
  }
}`,
  extensions: [jsonLanguage()],
});
const expectedSections = 'defs/thing,properties/name,properties/age';
for (const [state, format] of [
  [sectionJSON, 'json'],
  [sectionLegacyJSON, 'legacy JSON'],
  [sectionYamlJSC, 'jsc-yaml'],
  [sectionYSD, 'ysd'],
  [sectionYSDC, 'ysdc'],
  [sectionJSONYSDC, 'ysdc-json'],
]) {
  const sections = schemaSections(
    state,
    format === 'legacy JSON' ? 'json' : format,
  )
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
const normalHash = serializeEditorState({normal: true});
if (normalHash !== '#v=1&n=1') {
  throw new Error(`JSON normal URL is unstable: ${normalHash}`);
}
const parsedNormal = parseEditorState(normalHash);
if (!parsedNormal.ok || parsedNormal.state.normal !== true) {
  throw new Error(`JSON normal URL did not parse: ${normalHash}`);
}
if (serializeEditorState({normal: false}) !== '') {
  throw new Error('unchecked JSON normal state produced a fragment');
}
const strictHash = serializeEditorState({strict: true});
if (strictHash !== '#v=1&t=1') {
  throw new Error(`YAMLSchema strict URL is unstable: ${strictHash}`);
}
const parsedStrict = parseEditorState(strictHash);
if (!parsedStrict.ok || parsedStrict.state.strict !== true) {
  throw new Error(`YAMLSchema strict URL did not parse: ${strictHash}`);
}
if (serializeEditorState({strict: false}) !== '') {
  throw new Error('unchecked YAMLSchema strict state produced a fragment');
}
const normalizedStrictHash = serializeEditorState({
  normal: true,
  strict: true,
});
if (normalizedStrictHash !== '#v=1&t=1') {
  throw new Error(`normalized Strict URL is unstable: ${normalizedStrictHash}`);
}
const legacyNormalizedStrict = parseEditorState('#v=1&n=1&t=1');
if (
  !legacyNormalizedStrict.ok ||
  legacyNormalizedStrict.state.normal !== true ||
  legacyNormalizedStrict.state.strict !== true
) {
  throw new Error('legacy normalized Strict URL did not parse');
}
if (serializeEditorState({source: 'ysd'}) !== '') {
  throw new Error('canonical editor state produced a fragment');
}
for (const invalidHash of [
  '#v=2&s=ysd&z=x',
  '#v=1&s=ysd',
  '#v=1&s=ysd&z=not-gzip',
  '#v=1&n=0',
  '#v=1&t=0',
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
const labeledDiff = unifiedDiff(
  'before',
  'after',
  3,
  'openapi-3-schema.schema.json',
);
if (!labeledDiff.startsWith(
  '--- openapi-3-schema.schema.json\n+++ roundtrip\n',
)) {
  throw new Error(`unexpected labeled unified diff:\n${labeledDiff}`);
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

const preparedJSON = prepareJsonSchemaInput('{"a": [1, 2,],}');
if (preparedJSON.serialization !== 'json' ||
    preparedJSON.text !== '{"a": [1, 2]}') {
  throw new Error('JSON Schema JSON input was not detected');
}

const yamlSchemaText = `type: object
properties:
  name:
    type: string
required: [name]
`;
const preparedYAML = prepareJsonSchemaInput(yamlSchemaText);
if (preparedYAML.serialization !== 'yaml' ||
    preparedYAML.text !== yamlSchemaText) {
  throw new Error('JSON Schema YAML input was not detected');
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

const normalizedYAMLResult = globalThis.gloat.exports[
  'json-schema-normalize'
](yamlSchemaText);
const normalizedYAMLSchema = normalizedYAMLResult.ok
  ? JSON.parse(normalizedYAMLResult.value)
  : {};
if (!normalizedYAMLResult.ok ||
    normalizedYAMLSchema.properties?.name?.type !== 'string') {
  throw new Error(`YAML normalization failed: ${JSON.stringify(
    normalizedYAMLResult,
  )}`);
}
const preservedYAMLResult = globalThis.gloat.exports[
  'json-schema-normalize-yaml'
](yamlSchemaText);
if (!preservedYAMLResult.ok ||
    !preservedYAMLResult.value.startsWith(
      '$schema: https://json-schema.org/draft/2020-12/schema\n',
    ) ||
    !preservedYAMLResult.value.includes('  name:\n    type: string')) {
  throw new Error(`YAML normalization was not preserved: ${JSON.stringify(
    preservedYAMLResult,
  )}`);
}
const yamlYSDResult = globalThis.gloat.exports[
  'json-schema-to-ysd'
](yamlSchemaText);
const strictYamlYSDResult = globalThis.gloat.exports[
  'json-schema-to-ysd-strict'
](yamlSchemaText);
const yamlRoundtripResult = globalThis.gloat.exports[
  'json-schema-roundtrip-works'
](yamlSchemaText);
if (!yamlYSDResult.ok || !yamlYSDResult.value.includes('name: +Str') ||
    !yamlYSDResult.value.includes('.open: true') ||
    !strictYamlYSDResult.ok ||
    strictYamlYSDResult.value.includes('.open: true') ||
    !yamlRoundtripResult.ok || yamlRoundtripResult.value !== true) {
  throw new Error(`YAML JSON Schema conversion failed: ${JSON.stringify({
    yamlYSDResult,
    strictYamlYSDResult,
    yamlRoundtripResult,
  })}`);
}

const normalizedRefResult = globalThis.gloat.exports[
  'json-schema-normalize'
]('{"$defs":{"Contact":{"type":"object"}},' +
  '"$ref":"#/definitions/Contact"}');
const normalizedRefSchema = normalizedRefResult.ok
  ? JSON.parse(normalizedRefResult.value)
  : {};
if (
  !normalizedRefResult.ok ||
  normalizedRefSchema.$ref !== '#/$defs/Contact'
) {
  throw new Error(`unexpected normalized reference: ${JSON.stringify(
    normalizedRefResult,
  )}`);
}
const normalizedRefYSD = globalThis.gloat.exports[
  'json-schema-to-ysd'
](normalizedRefResult.value);
if (!normalizedRefYSD.ok) {
  throw new Error(`normalized reference conversion failed: ${JSON.stringify(
    normalizedRefYSD,
  )}`);
}

const strictInput = JSON.stringify({
  type: 'object',
  properties: {
    implicit: {
      type: 'object',
      properties: {name: {type: 'string'}},
    },
    explicitAny: {
      type: 'object',
      additionalProperties: true,
    },
    explicitEmpty: {
      type: 'object',
      additionalProperties: {},
    },
    combinedOpen: {
      type: 'object',
      allOf: [{type: 'object'}],
    },
    typed: {
      type: 'object',
      additionalProperties: {type: 'string'},
    },
    closed: {
      type: 'object',
      additionalProperties: false,
      properties: {
        reopened: {
          type: 'object',
          properties: {flag: {type: 'boolean'}},
        },
      },
    },
  },
});
const normalOpenYSD = globalThis.gloat.exports[
  'json-schema-to-ysd'
](strictInput);
if (
  !normalOpenYSD.ok ||
  !normalOpenYSD.value.includes('.open: true') ||
  !normalOpenYSD.value.includes('+Map{}') ||
  !normalOpenYSD.value.includes('+Str: +Any')
) {
  throw new Error(`normal open conversion changed: ${JSON.stringify(
    normalOpenYSD,
  )}`);
}
for (const operation of [
  'json-schema-to-ysd-strict',
  'json-schema-to-ysdc-strict',
]) {
  const result = globalThis.gloat.exports[operation](strictInput);
  const typedRule = operation === 'json-schema-to-ysd-strict'
    ? '+Map{+Str}'
    : '+Str: +Str';
  if (
    !result.ok ||
    result.value.includes('.open:') ||
    result.value.includes('+Str: +Any') ||
    result.value.includes('+Map{}') ||
    result.value.includes('+Map{+Any}') ||
    result.value.includes('+Map{+Str,+Any}') ||
    !result.value.includes(typedRule)
  ) {
    throw new Error(`invalid strict conversion: ${JSON.stringify({
      operation,
      result,
    })}`);
  }
}
const strictYSDCJSON = globalThis.gloat.exports[
  'json-schema-to-ysdc-json-strict'
](strictInput);
if (!strictYSDCJSON.ok) {
  throw new Error(`strict JSON .ysdc failed: ${JSON.stringify(
    strictYSDCJSON,
  )}`);
}
const strictYSDCData = JSON.parse(strictYSDCJSON.value);
const strictYSDCText = JSON.stringify(strictYSDCData);
if (
  strictYSDCText.includes('".open"') ||
  strictYSDCText.includes('"+Str":"+Any"') ||
  strictYSDCData['typed?']?.['+Str'] !== '+Str'
) {
  throw new Error(`invalid strict JSON .ysdc: ${strictYSDCJSON.value}`);
}
const strictYSD = globalThis.gloat.exports[
  'json-schema-to-ysd-strict'
](strictInput);
const strictJSON = strictYSD.ok
  ? globalThis.gloat.exports['ysd-to-json-schema'](strictYSD.value)
  : strictYSD;
const strictSchema = strictJSON.ok ? JSON.parse(strictJSON.value) : {};
if (
  !strictJSON.ok ||
  strictSchema.additionalProperties !== false ||
  strictSchema.properties?.implicit?.additionalProperties !== false ||
  strictSchema.properties?.explicitAny?.additionalProperties !== false ||
  strictSchema.properties?.explicitEmpty?.additionalProperties !== false ||
  strictSchema.properties?.combinedOpen?.allOf?.[0]
    ?.additionalProperties !== false ||
  strictSchema.properties?.closed?.properties?.reopened
    ?.additionalProperties !== false ||
  strictSchema.properties?.typed?.additionalProperties?.type !== 'string'
) {
  throw new Error(`strict JSON regeneration failed: ${JSON.stringify(
    strictJSON,
  )}`);
}
const strictYAML = globalThis.gloat.exports[
  'ysd-to-json-schema-yaml'
](strictYSD.value);
if (!strictYAML.ok ||
    !strictYAML.value.startsWith(
      '$schema: https://json-schema.org/draft/2020-12/schema\n',
    ) ||
    !strictYAML.value.includes('additionalProperties: false')) {
  throw new Error(`strict YAML regeneration failed: ${JSON.stringify(
    strictYAML,
  )}`);
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
  throw new Error(`.ysd conversion reordered properties: ${JSON.stringify(
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
  !appSource.includes('if (requestedSample) {') ||
  !appSource.includes('redirectEditorURL(initialSample, initialHash)') ||
  !appSource.includes('window.location.replace(url.href)')
) {
  throw new Error('base demo route does not select its default schema');
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
  if (!appSource.includes(
    `new URL('./${worker}?v=20', import.meta.url)`,
  )) {
    throw new Error(`${worker} is not used by the browser app`);
  }
}
if (!appSource.includes('roundtripWorker.terminate()')) {
  throw new Error('stale roundtrip work is not cancelled');
}
if (
  !appSource.includes('const workerResultCache = new ResultCache()') ||
  !appSource.includes('const roundtripResultCache = new ResultCache()') ||
  !appSource.includes('if (cached) return cached.promise;') ||
  !appSource.includes('const [toYSD, toYSDC] = await Promise.all([') ||
  !appSource.includes('if (!cachedVisible) showGeneratingYamlSchema();') ||
  !appSource.includes('if (!cached) showGeneratingJSONSchema();') ||
  !appSource.includes('showRoundtripResult(cached);') ||
  !appSource.includes('(roundtripBusy || roundtripTimer !== undefined)') ||
  !appSource.includes('cachedYSDCForYSD(ysd)') ||
  !appSource.includes(
    "jsonSchemaOutputOperation('json-schema-normalize')",
  )
) {
  throw new Error('generated documents are not reused for unchanged inputs');
}
if (!appSource.includes('roundtripDiffDialog.showModal()')) {
  throw new Error('roundtrip diff modal is not opened by the browser app');
}
if (
  !appSource.includes('function roundtripFilename(source)') ||
  !appSource.includes('`Roundtrip diff for ${roundtripDiffFilename}`') ||
  !appSource.includes('resultCacheKey([source, filename], input)') ||
  !appSource.includes(
    'getRoundtripWorker().postMessage({id, source, input, filename})',
  )
) {
  throw new Error('roundtrip diff does not identify its source filename');
}
if (
  !appSource.includes("updateRoundtripStatus('json', input)") ||
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
  !appSource.includes("updateRoundtripStatus('json', input, 0)") ||
  !appSource.includes("updateRoundtripStatus('ysd', yamlEditor.value, 0)")
) {
  throw new Error('focusing an editor does not start its roundtrip check');
}
for (const feature of [
  'lineNumbers({',
  'foldGutter()',
  'bracketMatching()',
  'setReadOnly(readOnly)',
  'setLanguage(language)',
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
  codeEditorSource.includes('EditorView.lineWrapping') ||
  !codeEditorSource.includes('const targetColumns = 80;') ||
  !codeEditorSource.includes('const maximumFontRem = 0.72;') ||
  !codeEditorSource.includes('const minimumFontRem = 0.55;') ||
  !codeEditorSource.includes('new ResizeObserver') ||
  !codeEditorSource.includes("measureText('0'.repeat(targetColumns))") ||
  !styleSource.includes('var(--editor-font-size, 0.72rem)/1.5')
) {
  throw new Error('editors do not fit 80 columns without wrapping');
}
if (
  !appSource.includes('parseEditorState(window.location.hash)') ||
  !appSource.includes('serializeEditorState({') ||
  !appSource.includes('Custom from ${origin}') ||
  !appSource.includes('replaceEditorURL(selectedSample, hash)')
) {
  throw new Error('shareable editor URL state is incomplete');
}
if (
  !appSource.includes('if (sharedState.content !== undefined)') ||
  !appSource.includes('canonicalSourceValues = {};') ||
  !appSource.includes('} else {\n    await loadSelectedSample(') ||
  !appSource.includes(
    'for (const select of Object.values(sampleSelects)) {\n' +
    '    select.disabled = false;\n  }\n\n' +
    '  if (sharedState.pane && sharedState.lines)',
  )
) {
  throw new Error('shared content initialization is incomplete');
}
if (
  !appSource.includes("setEditorValue(yamlEditor, 'Generating .ysdc...')") ||
  !appSource.includes("yamlFormat === 'ysdc' ? '.ysdc' : '.ysd'") ||
  !appSource.includes('showGeneratingYamlSchema();') ||
  !appSource.includes('const conversion = convertYamlToJson();') ||
  !appSource.includes('showGeneratingYSDC();')
) {
  throw new Error('old YAML remains visible while .ysd or .ysdc is generated');
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
  !appSource.includes("'[data-editor-help-open]'") ||
  !appSource.includes('for (const control of editorHelpOpenControls)') ||
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
  !appSource.includes('yamlschema.scroll-sync-source') ||
  !appSource.includes('yamlschema.ysdc-json') ||
  !appSource.includes('`json-schema-to-ysdc-json${strict}`') ||
  !appSource.includes("yamlPaneFormat() === 'ysdc-json' ? json() : yaml()") ||
  !appSource.includes('yamlEditor.setLanguage(language)') ||
  !appSource.includes("scrollSyncSource === 'current'") ||
  !appSource.includes('scrollSyncSourceControl.disabled') ||
  !appSource.includes('editor !== scrollSyncSourceEditor()') ||
  !appSource.includes('scrollToSchemaLocation') ||
  !appSource.includes('requestAnimationFrame')
) {
  throw new Error('editor settings or scroll synchronization is incomplete');
}
if (
  !appSource.includes('prepareJsonSchemaInput(text)') ||
  !appSource.includes("jsonSerialization === 'yaml' ? 'jsc-yaml'") ||
  !appSource.includes("serialization === 'yaml' ? yaml() : json()") ||
  !appSource.includes('jsonEditor.setLanguage(language)') ||
  !appSource.includes('prepareJsonSchema(jsonValue)') ||
  !appSource.includes('? jsonPaneFormat()')
) {
  throw new Error('JSON Schema serialization detection is incomplete');
}
if (
  !appSource.includes('navigator.share({title: \'YAMLSchema\', url})') ||
  !appSource.includes('navigator.clipboard?.writeText') ||
  !appSource.includes("setShareStatus('Link copied')")
) {
  throw new Error('editor sharing behavior is incomplete');
}
if (
  !appSource.includes("document.querySelectorAll('.editor-copy')") ||
  !appSource.includes('await copyText(editor.value)') ||
  !appSource.includes('void copyEditorText(button)') ||
  !appSource.includes('await copyText(roundtripDiff)') ||
  !appSource.includes('void copyRoundtripDiff()') ||
  !appSource.includes('void button.offsetWidth') ||
  !styleSource.includes('.schema-editor .editor-copy') ||
  !styleSource.includes('content: "Copied"') ||
  !styleSource.includes('animation: editor-copy-feedback 2s')
) {
  throw new Error('editor text copying behavior is incomplete');
}
if (
  !appSource.includes('setRoundtripSource(side)') ||
  !appSource.includes('indicator.dataset.roundtripSource')
) {
  throw new Error('roundtrip status does not follow the source pane');
}
if (
  !appSource.includes("person: {url: assetURL('examples/person.ysd.yaml')}") ||
  !appSource.includes(
    "yamlschema: {url: assetURL('examples/yamlschema.ysd.yaml')}",
  ) ||
  !appSource.includes(
    "url: assetURL('examples/harbor-next.schema.json')",
  ) ||
  !appSource.includes(
    "if (side === 'json') await showJsonSample(content, normal)",
  ) ||
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
  !appSource.includes('replaceEditorURL(initialSample, initialHash)')
) {
  throw new Error('editor schema routes do not select canonical inputs');
}
if (
  !appSource.includes('let jsonNormal = false;') ||
  !appSource.includes("let jsonValue = '';") ||
  !appSource.includes('const input = prepareJsonSchema(jsonValue);') ||
  !appSource.includes('setEditorValue(jsonEditor, jsonValue);') ||
  !appSource.includes('setJsonNormal(false);') ||
  !appSource.includes('setJsonNormal(true);') ||
  !appSource.includes("jsonNormalControl.addEventListener('click'") ||
  !appSource.includes('if (jsonNormal) {') ||
  !appSource.includes('event.preventDefault();') ||
  !appSource.includes("normal: documentSource === 'json' && jsonNormal") ||
  !appSource.includes('sharedState.normal === true')
) {
  throw new Error('JSON Schema Normal checkbox behavior is incomplete');
}
if (
  !appSource.includes('let ysdStrict = false;') ||
  !appSource.includes('let ysdStrictReady = false;') ||
  !appSource.includes("document.querySelector('#ysd-strict')") ||
  !appSource.includes("? 'json-schema-to-ysd-strict'") ||
  !appSource.includes('json-schema-to-ysdc-json${strict}') ||
  !appSource.includes('documentSource !== \'json\'') ||
  !appSource.includes('!ysdStrictReady;') ||
  !appSource.includes("'aria-disabled'") ||
  !appSource.includes('String(ysdStrictControl.disabled || ysdStrict)') ||
  !appSource.includes('setYSDStrictReady(false);') ||
  !appSource.includes('setYSDStrictReady(true);') ||
  !appSource.includes('async function makeJsonSchemaStrict()') ||
  !appSource.includes(
    'const canonicalSource = sourceValue === canonicalSourceValues.json;',
  ) ||
  !appSource.includes(
    'if (canonicalSource) canonicalSourceValues.json = jsonValue;',
  ) ||
  !appSource.includes("const operation = 'ysd-to-json-schema';") ||
  !appSource.includes(
    'showGeneratingJSONSchema();\n' +
    '  const result = cached || await callWorker(operation, conversion.ysd);',
  ) ||
  !appSource.includes('jsonValue = result.value;') ||
  !appSource.includes("ysdStrictControl.addEventListener('click'") ||
  !appSource.includes('if (ysdStrict) {') ||
  !appSource.includes("strict: documentSource === 'json' && ysdStrict") ||
  !appSource.includes('sharedState.strict === true') ||
  !appSource.includes(
    'initialStrict && sharedState.content !== undefined',
  ) ||
  !appSource.includes('if (initialStrict) await makeJsonSchemaStrict();')
) {
  throw new Error('YAMLSchema Strict checkbox behavior is incomplete');
}
const editorFocusedSource = appSource.slice(
  appSource.indexOf('function editorFocused(editor)'),
  appSource.indexOf('function scrollSyncSourceEditor()'),
);
if (
  editorFocusedSource.includes('setYSDStrict(false)') ||
  !appSource.includes(
    'setJsonNormal(false);\n  setYSDStrict(false);\n' +
    '  setYSDStrictReady(false);',
  ) ||
  !appSource.includes(
    'documentSource = source;\n    setYSDStrict(false);\n' +
    '    setYSDStrictReady(false);',
  )
) {
  throw new Error('Strict state is not reset only by JSON content changes');
}
if (
  !styleSource.includes('.strict-control:has(input:disabled)') ||
  !styleSource.includes('.normal-control:has(input:disabled)') ||
  !styleSource.includes('color: var(--editor-muted);') ||
  !styleSource.includes('.strict-control:has(input:checked)') ||
  !styleSource.includes('.normal-control:has(input:checked)') ||
  !styleSource.includes('accent-color: var(--editor-string);')
) {
  throw new Error('Strict and Normal control states are not styled');
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
  !styleSource.includes('body:has(.schema-editor) {\n    overflow: hidden;') ||
  !styleSource.includes('.schema-editor .editor-pane {\n    min-height: 0;') ||
  !styleSource.includes('height: 100%;\n    max-height: 100%;') ||
  !styleSource.includes('.schema-editor .error:empty')
) {
  throw new Error('both editor panes do not fit in the portrait layout');
}
const roundtripWorkerSource = await readFile(
  'docs/assets/editor/roundtrip-worker.js',
  'utf8',
);
if (
  !roundtripWorkerSource.includes("importScripts('unified-diff.js?v=2')") ||
  !roundtripWorkerSource.includes("fetch('ysd.wasm?v=20')") ||
  !roundtripWorkerSource.includes("'json-schema-roundtrip-report'") ||
  !roundtripWorkerSource.includes("'ysd-roundtrip-report'") ||
  !roundtripWorkerSource.includes(
    'function checkRoundtrip({id, source, input, filename})',
  ) ||
  !roundtripWorkerSource.includes('filename,\n    });')
) {
  throw new Error('roundtrip worker does not generate browser diffs');
}
const schemaWorkerSource = await readFile(
  'docs/assets/editor/schema-worker.js',
  'utf8',
);
if (!schemaWorkerSource.includes("fetch('ysd.wasm?v=20')")) {
  throw new Error('schema worker does not load the current Wasm asset');
}
for (const operation of [
  'json-schema-normalize-yaml',
  'json-schema-to-ysd-strict',
  'json-schema-to-ysdc-strict',
  'json-schema-to-ysdc-json-strict',
  'ysd-to-json-schema-yaml',
]) {
  if (!schemaWorkerSource.includes(`'${operation}'`)) {
    throw new Error(`schema worker is missing ${operation}`);
  }
}

const pastedYSD = await readFile('test/ansible-builder.ysd.yaml', 'utf8');
const pastedResult = globalThis.gloat.exports['ysd-to-json-schema'](
  pastedYSD,
);
if (!pastedResult.ok) {
  throw new Error(`pasted .ysd conversion failed: ${JSON.stringify(
    pastedResult,
  )}`);
}
const pastedRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](pastedYSD);
if (!pastedRoundtrip.ok || pastedRoundtrip.value !== true) {
  throw new Error(`unexpected pasted .ysd roundtrip: ${JSON.stringify(
    pastedRoundtrip,
  )}`);
}

const yamlschemaYSD = await readFile(
  'docs/assets/editor/examples/yamlschema.ysd.yaml',
  'utf8',
);
const yamlschemaResult = globalThis.gloat.exports[
  'ysd-to-json-schema'
](yamlschemaYSD);
const yamlschemaRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](yamlschemaYSD);
if (
  !yamlschemaResult.ok ||
  JSON.parse(yamlschemaResult.value).$id !==
    'https://yamlschema.org/schema/yamlschema.schema.json' ||
  !yamlschemaRoundtrip.ok ||
  yamlschemaRoundtrip.value !== true
) {
  throw new Error(`YAMLSchema meta-schema failed: ${JSON.stringify({
    conversion: yamlschemaResult,
    roundtrip: yamlschemaRoundtrip,
  })}`);
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
  'harbor-next',
  'openqa-job-templates',
  'openapi-3-schema',
  'petstore',
  'netbox-generated',
];
const routedExamples = [
  ['person', 'ysd'],
  ['yamlschema', 'ysd'],
  ...exampleFiles.map((name) => [name, 'json']),
];
const indexHTML = await readFile('site/demo/index.html', 'utf8');
const demoPrimaryStart = indexHTML.indexOf('md-sidebar--primary');
const demoSecondaryStart = indexHTML.indexOf('md-sidebar--secondary');
const demoPrimarySidebar = indexHTML.slice(
  demoPrimaryStart,
  demoSecondaryStart,
);
if (
  demoPrimaryStart < 0 ||
  demoSecondaryStart < 0 ||
  demoPrimarySidebar.includes(' hidden') ||
  !demoPrimarySidebar.includes('md-nav--primary')
) {
  throw new Error('demo mobile navigation drawer is missing');
}
const mkdocsConfig = await readFile('mkdocs.yaml', 'utf8');
const jsonSchemaReference = await readFile(
  'docs/reference/json-schema.md',
  'utf8',
);
if (
  !mkdocsConfig.includes(
    'analytics:\n    provider: custom\n    property: G-EFBDLGET7X',
  ) ||
  !indexHTML.includes('G-EFBDLGET7X') ||
  !indexHTML.includes('id="gdpr-cookie-banner"') ||
  !indexHTML.includes('localStorage.getItem("cookie_consent")') ||
  indexHTML.includes('<script id="__analytics">') ||
  !indexHTML.includes('/assets/editor/app.js?v=24') ||
  mkdocsConfig.includes('- YAMLSchema:') ||
  !mkdocsConfig.includes(
    'nav:\n- Getting Started: getting-started.md\n- Demos: demo/index.md',
  ) ||
  !mkdocsConfig.includes(
    '  - Design: reference/design.md\n- Blog: blog/index.md',
  ) ||
  !mkdocsConfig.includes('plugins:\n- blog\n- search:')
) {
  throw new Error('site navigation has incorrect home or demo tabs');
}
if (
  !indexHTML.includes('<a href=".." title="YAMLSchema"') ||
  !indexHTML.includes('<a href=".." class="md-header__title"') ||
  !indexHTML.includes('aria-label="YAMLSchema home"')
) {
  throw new Error('header icon and title do not link to the home page');
}
if (
  !indexHTML.includes('id="json-schema-title"') ||
  !indexHTML.includes('<label title="YAMLSchema Definition">\n' +
    '            <input type="radio" name="yaml-format" value="ysd" ' +
    'checked>\n            .ysd') ||
  !indexHTML.includes('<label title="YAMLSchema Definition Canonical">\n' +
    '            <input type="radio" name="yaml-format" value="ysdc">' +
    '\n            .ysdc') ||
  !indexHTML.includes('<label class="normal-control"\n' +
    '                 title="Normalized/Canonical Form">\n' +
    '            <input type="checkbox" id="json-normal" disabled>\n' +
    '            Normal') ||
  !indexHTML.includes('class="strict-control"') ||
  !indexHTML.includes(
    'title="Close unconstrained JSON Schema mappings"',
  ) ||
  !indexHTML.includes('<input type="checkbox" id="ysd-strict" disabled>') ||
  indexHTML.includes('name="json-view"') ||
  indexHTML.includes('id="normalize-json"') ||
  !indexHTML.includes('id="editor-settings-open"') ||
  !indexHTML.includes('aria-label="Open editor settings"') ||
  !indexHTML.includes('class="editor-actions"') ||
  !indexHTML.includes('id="editor-help-button"') ||
  !indexHTML.includes('data-editor-help-open') ||
  !indexHTML.includes('aria-label="Open editor help"') ||
  !indexHTML.includes('id="editor-share"') ||
  indexHTML.indexOf('id="editor-help-button"') >
    indexHTML.indexOf('id="editor-share"') ||
  !indexHTML.includes('aria-label="Share editor link"') ||
  !indexHTML.includes('data-copy-editor="yaml"') ||
  !indexHTML.includes('aria-label="Copy YAMLSchema text"') ||
  !indexHTML.includes('data-copy-editor="json"') ||
  !indexHTML.includes('aria-label="Copy JSON Schema text"') ||
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
  !styleSource.includes(
    'body:has(.schema-editor) .md-main__inner',
  ) ||
  !styleSource.includes(
    'body:has(.schema-editor) .md-sidebar--primary {\n' +
    '    display: none;',
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
  !indexHTML.includes('How roundtrip checking works') ||
  !indexHTML.includes('Expands .ysd into canonical .ysdc') ||
  !indexHTML.includes('Normalizes it as draft 2020-12 JSON Schema') ||
  !indexHTML.includes('Compares the original and regenerated .ysdc') ||
  !indexHTML.includes('canonical original and the canonical roundtrip') ||
  !indexHTML.includes('Understand roundtrip status') ||
  !indexHTML.includes('Generated JSON Schema is marked Normal') ||
  !indexHTML.includes('JSON Schema may be written as JSON or YAML') ||
  !indexHTML.includes('Editing the JSON Schema clears that mark') ||
  !indexHTML.includes('Select Normal to replace edited JSON Schema') ||
  !indexHTML.includes('Strict becomes available after editable JSON Schema') ||
  !indexHTML.includes('Strict removes `.open` directives and suppresses ' +
    'open-map forms such') ||
  !indexHTML.includes('Once applied, Strict remains checked') ||
  !indexHTML.includes('Editing the JSON Schema clears Strict') ||
  !indexHTML.includes('Share content and lines')
) {
  throw new Error('editor help instructions are incomplete');
}
if (
  !jsonSchemaReference.includes('## Strict Editor Conversion') ||
  !jsonSchemaReference.includes('removing `.open` directives') ||
  !jsonSchemaReference.includes('open-map forms such as `+Map{}`') ||
  !jsonSchemaReference.includes('`additionalProperties: false`') ||
  !jsonSchemaReference.includes('Strict remains checked and disabled') ||
  !jsonSchemaReference.includes('Editing the JSON Schema clears Strict')
) {
  throw new Error('Strict interoperability documentation is incomplete');
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
  !indexHTML.includes('id="scroll-sync-source"') ||
  !/name="scroll-sync-source" value="ysd"\s+checked/.test(indexHTML) ||
  !indexHTML.includes('name="scroll-sync-source" value="json"') ||
  !indexHTML.includes('name="scroll-sync-source" value="current"') ||
  !indexHTML.includes('id="ysdc-json"') ||
  !indexHTML.includes('<strong>.ysdc as JSON</strong>') ||
  !indexHTML.includes('id="factory-reset"') ||
  !appSource.includes('localStorage.clear()') ||
  !appSource.includes('sessionStorage.clear()') ||
  !appSource.includes('window.location.assign(editRootURL.href)') ||
  !appSource.includes(
    "factoryResetControl.addEventListener('click', factoryResetSite)",
  ) ||
  !indexHTML.includes('YAMLSchema always uses the left pane') ||
  !indexHTML.includes('Factory Reset immediately clears all site settings') ||
  !styleSource.includes('.schema-editor #editor-settings-dialog') ||
  !styleSource.includes('.editor-setting-options:disabled') ||
  !styleSource.includes('.schema-editor #factory-reset')
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
  !styleSource.includes(
    '.editor-help-link {\n  color: var(--md-default-fg-color)',
  ) ||
  !styleSource.includes(
    'border-radius: 50%;\n  color: var(--md-typeset-a-color)',
  ) ||
  !styleSource.includes('.schema-editor .editor-help-link:focus-visible')
) {
  throw new Error('YAMLSchema help link is not styled as a link');
}
if (
  styleSource.includes('flex-wrap: wrap') ||
  !styleSource.includes('min-width: 0;\n    flex: 1 1 0;') ||
  !styleSource.includes('@media (max-width: 1200px)') ||
  !styleSource.includes(
    '.schema-editor .format-selector,\n' +
    '  .schema-editor .strict-control {\n    display: none;',
  ) ||
  !styleSource.includes(
    '.schema-editor .cm-gutters {\n    display: none !important;',
  )
) {
  throw new Error('mobile editor layout is incomplete');
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
for (const name of ['person', 'yamlschema']) {
  if (!yamlSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is missing from the YAMLSchema selector`);
  }
  if (jsonSelectHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is incorrectly in the JSON Schema selector`);
  }
}
if (yamlSelectHTML.indexOf('value="person"') >
    yamlSelectHTML.indexOf('value="yamlschema"')) {
  throw new Error('YAMLSchema example order is wrong');
}
if (jsonSelectHTML.indexOf('value="netbox-generated"') <
    jsonSelectHTML.indexOf('value="ansible-builder"')) {
  throw new Error('NetBox Generated is not the last JSON Schema example');
}
if (
  !indexHTML.includes('id="roundtrip-diff-dialog"') ||
  !indexHTML.includes('id="roundtrip-diff-title"') ||
  !indexHTML.includes('id="roundtrip-diff"') ||
  !indexHTML.includes('id="roundtrip-diff-copy"') ||
  !indexHTML.includes('aria-label="Copy roundtrip diff text"') ||
  !indexHTML.includes('id="roundtrip-diff-close"') ||
  !indexHTML.includes('aria-label="Close roundtrip diff"')
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
const siteStyleSource = await readFile('docs/css/extra.css', 'utf8');
if (!homeHTML.includes('Define a lot more')) {
  throw new Error('home page tagline is missing');
}
if (
  !siteStyleSource.includes(
    '.md-typeset .home-hero h1 > span {\n  white-space: nowrap;',
  ) ||
  !siteStyleSource.includes(
    '.md-typeset .home-eyebrow {\n    font-size: 0.7rem;',
  )
) {
  throw new Error('home page headline is not responsive');
}
if (!homeHTML.includes('Try the Demos')) {
  throw new Error('home page does not link to the demos');
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
const blogHTML = await readFile('site/blog/index.html', 'utf8');
const introducingPostHTML = await readFile(
  'site/blog/2026/08/30/introducing-yamlschema/index.html',
  'utf8',
);
const blogArchiveHTML = await readFile(
  'site/blog/archive/2026/index.html',
  'utf8',
);
const blogCategoryHTML = await readFile(
  'site/blog/category/yamlschema/index.html',
  'utf8',
);
if (
  !blogHTML.includes('YAMLSchema Blog') ||
  !blogHTML.includes('Introducing YAMLSchema') ||
  !blogHTML.includes('Ingy döt Net') ||
  !blogHTML.includes('Continue reading') ||
  blogHTML.includes('Schema That Mimics the Data') ||
  !introducingPostHTML.includes('Introducing YAMLSchema') ||
  !introducingPostHTML.includes('https://github.com/ingydotnet') ||
  !introducingPostHTML.includes('href="../../../../../demo/"') ||
  !introducingPostHTML.includes('https://github.com/yaml/yamlschema') ||
  !blogArchiveHTML.includes('Introducing YAMLSchema') ||
  !blogCategoryHTML.includes('Introducing YAMLSchema')
) {
  throw new Error('YAMLSchema blog output is incomplete');
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
for (const page of [
  'getting-started',
  'examples',
  'cheat-sheet',
  'cli',
]) {
  const html = await readFile(`site/${page}/index.html`, 'utf8');
  const primaryStart = html.indexOf('md-sidebar--primary');
  const secondaryStart = html.indexOf('md-sidebar--secondary');
  const primarySidebar = html.slice(primaryStart, secondaryStart);
  if (
    primaryStart < 0 ||
    secondaryStart < 0 ||
    primarySidebar.includes(' hidden') ||
    primarySidebar.includes('md-nav--primary')
  ) {
    throw new Error(`${page} does not have an empty primary sidebar`);
  }
}
const cname = await readFile('site/CNAME', 'utf8');
if (cname.trim() !== 'yamlschema.org') {
  throw new Error(`unexpected CNAME: ${cname}`);
}
for (const endpoint of [
  'complete.ps1',
  'install',
  'install.mk',
  'install.ps1',
]) {
  const source = await readFile(`docs/${endpoint}`, 'utf8');
  const built = await readFile(`site/${endpoint}`, 'utf8');
  if (built !== source) {
    throw new Error(`${endpoint} was not copied unchanged`);
  }
}
const powerShellInstaller = await readFile('docs/install.ps1', 'utf8');
if (
  !powerShellInstaller.includes("[string]$Version = '0.1.6'") ||
  !powerShellInstaller.includes("'X64' { 'amd64' }") ||
  !powerShellInstaller.includes("'Arm64' { 'arm64' }") ||
  !powerShellInstaller.includes('Invoke-WebRequest @Request') ||
  !powerShellInstaller.includes(
    "[Environment]::SetEnvironmentVariable(\n        'Path'",
  ) ||
  !powerShellInstaller.includes(
    "$CompletionUrl = 'https://yamlschema.org/complete.ps1'",
  ) ||
  !powerShellInstaller.includes('$PROFILE.CurrentUserAllHosts') ||
  !powerShellInstaller.includes('. $CompletionFile') ||
  !powerShellInstaller.includes('$ProfileLines -notcontains $ProfileLine') ||
  !powerShellInstaller.includes('& $Executable --version')
) {
  throw new Error('PowerShell installer behavior is incomplete');
}
const powerShellCompletion = await readFile('docs/complete.ps1', 'utf8');
const completionOptions = [
  '-t', '--to', '-f', '--from', '-o', '--output',
  '-Y', '--yaml', '-J', '--json', '-N', '--norm',
  '-R', '--roundtrip', '-q', '--quiet', '-C', '--compact',
  '--upgrade', '--help', '--version',
];
const completionSuffixes = [
  '.ysd.yaml', '.ysd.json', '.ysdc.yaml', '.ysdc.json',
  '.schema.json', '.schema.json.yaml', '.schema.yaml', '.schema.yml',
];
if (
  !powerShellCompletion.includes(
    'Register-ArgumentCompleter -Native -CommandName ysd',
  ) ||
  !powerShellCompletion.includes('Complete-YsdPath $WordToComplete $true') ||
  !completionOptions.every((option) =>
    powerShellCompletion.includes(`'${option}'`)) ||
  !completionSuffixes.every((suffix) =>
    powerShellCompletion.includes(`'${suffix}'`))
) {
  throw new Error('PowerShell completion behavior is incomplete');
}
const homeSource = await readFile('docs/index.md', 'utf8');
if (
  !homeSource.includes('source <(curl -sL yamlschema.org/install)') ||
  !homeSource.includes('curl -sL yamlschema.org/install | source -') ||
  !homeSource.includes('irm https://yamlschema.org/install.ps1 | iex') ||
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
  !gettingStartedSource.includes('Try `ysd --<TAB>` or `man ysd`') ||
  !gettingStartedSource.includes(
    'irm https://yamlschema.org/install.ps1 | iex',
  ) ||
  !gettingStartedSource.includes(
    'adds the completion script\n' +
      'to `$PROFILE.CurrentUserAllHosts` for future PowerShell sessions.',
  ) ||
  !gettingStartedSource.includes(
    'Native Windows man pages are not available',
  )
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
  const suffix = name === 'openqa-job-templates'
    ? 'schema.yaml'
    : 'schema.json';
  const text = await readFile(
    `docs/assets/editor/examples/${name}.${suffix}`,
    'utf8',
  );
  let schema;
  if (name === 'openqa-job-templates') {
    const normalized = globalThis.gloat.exports[
      'json-schema-normalize'
    ](text);
    if (!normalized.ok ||
        !text.includes(
          '$schema: http://json-schema.org/draft-04/schema#',
        )) {
      throw new Error(`${name} normalization failed: ${JSON.stringify(
        normalized,
      )}`);
    }
    schema = JSON.parse(normalized.value);
  } else {
    schema = JSON.parse(text);
  }
  const dialect = name === 'openapi-3-schema'
    ? 'http://json-schema.org/draft-04/schema#'
    : 'https://json-schema.org/draft/2020-12/schema';
  if (name !== 'openqa-job-templates' && schema.$schema &&
      schema.$schema !== dialect) {
    throw new Error(`${name} has the wrong JSON Schema dialect`);
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
  if (name === 'petstore') {
    if (
      schema.title !== 'OpenAPI PetStore' ||
      Object.keys(schema.$defs).length !== 5 ||
      schema.properties.category.$ref !== '#/$defs/Category' ||
      roundtrip.value !== true
    ) {
      throw new Error('OpenAPI PetStore schema is incorrect');
    }
  }
  if (name === 'harbor-next') {
    const ysdc = globalThis.gloat.exports['json-schema-to-ysdc'](text);
    if (
      schema.title !== 'Harbor Next Helm Chart Values' ||
      roundtrip.value !== true ||
      !ysdc.ok ||
      !ysdc.value.includes('.range: [1, 100]')
    ) {
      throw new Error(`Harbor Next schema is incorrect: ${JSON.stringify({
        roundtrip,
        ysdc,
      })}`);
    }
  }
  if (name === 'openqa-job-templates') {
    if (
      !text.includes(
        '$id: http://open.qa/api/schema/JobTemplates-01.yaml',
      ) ||
      schema.description !== 'openQA job template' ||
      roundtrip.value !== true ||
      !converted.value.includes('+Tup{+Str?,+Any...}') ||
      !converted.value.includes(
        '/^\\.[a-z0-9_]+$/: +Map{} ' +
        '-"Definitions that can be re-used"',
      ) ||
      !converted.value.includes('+Str~ ~"[\\p{Word} _*.+-]+"')
    ) {
      throw new Error('openQA Job Templates schema is incorrect');
    }
  }
  if (name === 'openapi-3-schema') {
    if (
      schema.id !==
        'https://spec.openapis.org/oas/3.0/schema/2024-10-18' ||
      Object.keys(schema.definitions).length !== 42 ||
      roundtrip.value !== true
    ) {
      const report = globalThis.gloat.exports[
        'json-schema-roundtrip-report'
      ](text);
      throw new Error(`OpenAPI 3.0 schema is incorrect: ${JSON.stringify({
        id: schema.id,
        definitions: Object.keys(schema.definitions).length,
        roundtrip,
        report,
      })}`);
    }
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
      throw new Error('address dependencies are missing from .ysd');
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
        throw new Error(`device-type .ysd is missing: ${expected}`);
      }
    }
  }
}

const initialYSD = await readFile(
  'docs/assets/editor/examples/person.ysd.yaml',
  'utf8',
);
const expectedInitialYSD = String.raw`name: +Str 3-30 ~"{upper}{lower}+ {upper}{lower}+"
age: +Int 0..120
married?: +Bool =false
address: +address
phone: +Str[$1-3] ~"{plus}1-{digit}{3}-{digit}{3}-{digit}{4}"
attributes?:
  strength: +Num 0..10
  dexterity: +Num 0..10
  wisdom: +Num 0..10

+address:
  street: +Str
    ~"({digit}+ )?{upper}{lower}+( {upper}{lower}+)*
      (St|Ave|Blvd|Rd|Ln|Dr)\.?"
  city: +Str ~"{upper}{lower}+( {upper}{lower}+)*"
  state: +Str ~"{upper}{2}"
  postal code: +Str ~"{digit}{5}(-{digit}{4})?"
`;
if (initialYSD !== expectedInitialYSD) {
  throw new Error(`unexpected Person .ysd: ${initialYSD}`);
}
const initialResult = globalThis.gloat.exports['ysd-to-json-schema'](
  initialYSD,
);
if (!initialResult.ok) {
  throw new Error(`initial .ysd conversion failed: ${JSON.stringify(
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
  initialJSON.required.join(',') !== 'name,age,address,phone' ||
  Object.keys(initialJSON.properties).join(',') !==
    'name,age,married,address,phone,attributes' ||
  initialJSON.properties.name.type !== 'string' ||
  initialJSON.properties.name.minLength !== 3 ||
  initialJSON.properties.name.maxLength !== 30 ||
  initialJSON.properties.name.pattern !==
    '^[A-Z][a-z]+ [A-Z][a-z]+$' ||
  initialJSON.properties.age.type !== 'integer' ||
  initialJSON.properties.age.minimum !== 0 ||
  initialJSON.properties.age.maximum !== 120 ||
  initialJSON.properties.married.default !== false ||
  initialJSON.properties.address.$ref !== '#/$defs/address' ||
  initialJSON.properties.phone.anyOf[1].minItems !== 1 ||
  initialJSON.properties.phone.anyOf[1].maxItems !== 3 ||
  initialJSON.properties.attributes.properties.strength.maximum !== 10 ||
  initialJSON.$defs.address.properties.state.pattern !== '^[A-Z]{2}$'
) {
  throw new Error(`unexpected initial JSON: ${initialResult.value}`);
}
const initialBackToYSD = globalThis.gloat.exports['json-schema-to-ysd'](
  initialResult.value,
);
if (
  !initialBackToYSD.ok ||
  !initialBackToYSD.value.includes(
    'phone: +Str[$1-3] ' +
      '~"{plus}1-{digit}{3}-{digit}{3}-{digit}{4}"',
  )
) {
  throw new Error(`unexpected regenerated Person .ysd: ${JSON.stringify(
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
  'dateOfBirth: +JSON-Schema/date',
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
  throw new Error(`JSON to .ysd failed: ${JSON.stringify(toYSD)}`);
}

const toJSON = globalThis.gloat.exports['ysd-to-json-schema'](toYSD.value);
if (!toJSON.ok ||
    JSON.parse(toJSON.value).$id !==
      'https://example.com/person.schema.json' ||
    JSON.parse(toJSON.value).type !== 'object') {
  throw new Error(`.ysd to JSON failed: ${JSON.stringify(toJSON)}`);
}

const toYSDC = globalThis.gloat.exports['json-schema-to-ysdc'](json);
const toJSONYSDC = globalThis.gloat.exports[
  'json-schema-to-ysdc-json'
](json);
const expectedYSDC =
  '.ysid: https://example.com/person.ysd.yaml\n' +
  '.open: true\nname: +Str';
if (!toYSDC.ok || toYSDC.value !== expectedYSDC) {
  throw new Error(`JSON to .ysdc failed: ${JSON.stringify(toYSDC)}`);
}
const parsedJSONYSDC = toJSONYSDC.ok && JSON.parse(toJSONYSDC.value);
if (!parsedJSONYSDC ||
    parsedJSONYSDC['.ysid'] !==
      'https://example.com/person.ysd.yaml' ||
    parsedJSONYSDC['.open'] !== true ||
    parsedJSONYSDC.name !== '+Str') {
  throw new Error(
    `JSON to JSON .ysdc failed: ${JSON.stringify(toJSONYSDC)}`,
  );
}

const closedYSDC = globalThis.gloat.exports[
  'json-schema-to-ysdc'
](initialResult.value);
if (!closedYSDC.ok || closedYSDC.value.includes('.open: true')) {
  throw new Error(`closed JSON produced open .ysdc: ${JSON.stringify(
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
  throw new Error(`expected .ysd roundtrip failure: ${JSON.stringify(
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
  throw new Error(`invalid .ysd roundtrip report: ${JSON.stringify(
    failedYSDReportResult,
  )}`);
}

for (const invalidYSD of [
  'bad: [',
  '.unknown: true',
  'name: +Stx',
  'name: +Map(',
  'name: +Map(+Any)',
]) {
  const result = globalThis.gloat.exports['ysd-to-json-schema'](invalidYSD);
  if (result.ok || !result.error) {
    throw new Error(`invalid .ysd did not return an error: ${invalidYSD}`);
  }
  const report = globalThis.gloat.exports['ysd-roundtrip-report'](
    invalidYSD,
  );
  if (report.ok || !report.error) {
    throw new Error(`invalid .ysd roundtrip did not fail: ${invalidYSD}`);
  }
}

console.log('browser exports converted .ysd, .ysdc, and JSON');
process.exit(0);
