import '../site/wasm_exec.js';
import {readFile} from 'node:fs/promises';
import {normalizeJson} from '../src/json.js';
await import('../src/unified-diff.js');

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
const bytes = await readFile('ysc.wasm');
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
  '../src/examples/blog-post.schema.json',
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

const appSource = await readFile('../src/app.js', 'utf8');
const styleSource = await readFile('../src/style.css', 'utf8');
if (appSource.includes('globalThis.gloat')) {
  throw new Error('the browser app calls Wasm on the UI thread');
}
for (const worker of ['schema-worker.js', 'roundtrip-worker.js']) {
  if (!appSource.includes(`new Worker('${worker}`)) {
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
  !appSource.includes(
    "jsonEditor.addEventListener('focus', () => roundtripOnFocus(jsonEditor))",
  ) ||
  !appSource.includes(
    "yamlEditor.addEventListener('focus', () => roundtripOnFocus(yamlEditor))",
  ) ||
  !appSource.includes("updateRoundtripStatus('json', json, 0)") ||
  !appSource.includes("updateRoundtripStatus('ysd', yamlEditor.value, 0)")
) {
  throw new Error('focusing an editor does not start its roundtrip check');
}
if (
  !appSource.includes("setEditorValue(yamlEditor, 'Generating YSC...')") ||
  !appSource.includes("yamlFormat === 'ysc' ? 'YSC' : 'YSD'") ||
  !appSource.includes('showGeneratingYamlSchema();') ||
  !appSource.includes('const conversion = convertYamlToJson();') ||
  !appSource.includes('showGeneratingYSC();')
) {
  throw new Error('old YAML remains visible while YSD or YSC is generated');
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
  !appSource.includes('setRoundtripSource(sample.format)') ||
  !appSource.includes('indicator.dataset.roundtripSource')
) {
  throw new Error('roundtrip status does not follow the source pane');
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
const roundtripWorkerSource = await readFile(
  '../src/roundtrip-worker.js',
  'utf8',
);
if (
  !roundtripWorkerSource.includes("importScripts('unified-diff.js?v=1')") ||
  !roundtripWorkerSource.includes("'json-schema-roundtrip-report'") ||
  !roundtripWorkerSource.includes("'ysd-roundtrip-report'")
) {
  throw new Error('roundtrip worker does not generate browser diffs');
}

const pastedYSD = await readFile('../test/ansible-builder.ysd.yaml', 'utf8');
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
];
const indexHTML = await readFile('index.html', 'utf8');
if (!indexHTML.includes('id="normalize-json"')) {
  throw new Error('Normalize JSON button is missing');
}
for (const source of ['ysd', 'json']) {
  if (!indexHTML.includes(`data-roundtrip-source="${source}"`)) {
    throw new Error(`${source} roundtrip status source is missing`);
  }
}
if (indexHTML.includes('<optgroup')) {
  throw new Error('sample selector is not flat');
}
const sampleOrder = ['person', ...exampleFiles, 'harbor-next'];
let previousSample = -1;
for (const name of sampleOrder) {
  const position = indexHTML.indexOf(`value="${name}"`);
  if (position <= previousSample) {
    throw new Error(`sample selector order is wrong at ${name}`);
  }
  previousSample = position;
}
if (
  !indexHTML.includes('id="roundtrip-diff-dialog"') ||
  !indexHTML.includes('id="roundtrip-diff"')
) {
  throw new Error('roundtrip diff dialog is missing');
}
for (const name of exampleFiles) {
  if (!indexHTML.includes(`value="${name}"`)) {
    throw new Error(`${name} is missing from the sample selector`);
  }
  const text = await readFile(`examples/${name}.schema.json`, 'utf8');
  const schema = JSON.parse(text);
  if (schema.$schema !== 'https://json-schema.org/draft/2020-12/schema') {
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
}

const initialYSD = `.title: Person
age?: +Int 0..
name: +Str`;
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
  initialJSON.title !== 'Person' ||
  initialJSON.type !== 'object' ||
  initialJSON.additionalProperties !== false ||
  initialJSON.required.join(',') !== 'name' ||
  Object.keys(initialJSON.properties).join(',') !== 'age,name' ||
  initialJSON.properties.age.type !== 'integer' ||
  initialJSON.properties.age.minimum !== 0 ||
  initialJSON.properties.name.type !== 'string'
) {
  throw new Error(`unexpected initial JSON: ${initialResult.value}`);
}
const initialRoundtrip = globalThis.gloat.exports[
  'ysd-roundtrip-works'
](initialYSD);
if (!initialRoundtrip.ok || initialRoundtrip.value !== true) {
  throw new Error(`unexpected initial roundtrip: ${JSON.stringify(
    initialRoundtrip,
  )}`);
}

const harborYSD = await readFile('values.ysd.yaml', 'utf8');
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
const harborKeys = Object.keys(harborJSON).slice(0, 6).join(',');
const expectedHarborKeys = '$id,$schema,title,description,type,properties';
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
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  required: ['name'],
  properties: {name: {type: 'string'}},
});
const toYSD = globalThis.gloat.exports['json-schema-to-ysd'](json);
if (!toYSD.ok || !toYSD.value.includes('name:')) {
  throw new Error(`JSON to YSD failed: ${JSON.stringify(toYSD)}`);
}

const toJSON = globalThis.gloat.exports['ysd-to-json-schema'](toYSD.value);
if (!toJSON.ok || JSON.parse(toJSON.value).type !== 'object') {
  throw new Error(`YSD to JSON failed: ${JSON.stringify(toJSON)}`);
}

const toYSC = globalThis.gloat.exports['json-schema-to-ysc'](json);
const expectedYSC = '.open: true\nname: +Str';
if (!toYSC.ok || toYSC.value !== expectedYSC) {
  throw new Error(`JSON to YSC failed: ${JSON.stringify(toYSC)}`);
}

const closedYSC = globalThis.gloat.exports[
  'json-schema-to-ysc'
](initialResult.value);
if (!closedYSC.ok || closedYSC.value.includes('.open: true')) {
  throw new Error(`closed JSON produced open YSC: ${JSON.stringify(
    closedYSC,
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

console.log('browser exports converted YSD, YSC, and JSON');
process.exit(0);
