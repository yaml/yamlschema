import {gzipSync, gunzipSync, strFromU8, strToU8} from 'fflate';

const stateVersion = '1';
const sourceNames = new Set(['ysd', 'json']);
const paneNames = new Set(['ysd', 'ysdc', 'json']);

function bytesToBase64Url(bytes) {
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/, '');
}

function base64UrlToBytes(value) {
  if (!/^[A-Za-z0-9_-]*$/.test(value)) {
    throw new Error('invalid Base64URL content');
  }
  const base64 = value.replaceAll('-', '+').replaceAll('_', '/');
  const padded = base64 + '='.repeat((4 - base64.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export function encodeContent(content) {
  return bytesToBase64Url(gzipSync(strToU8(content), {level: 9}));
}

export function decodeContent(encoded) {
  return strFromU8(gunzipSync(base64UrlToBytes(encoded)));
}

export function parseLineRange(value) {
  const match = /^(\d+)(?:-(\d+))?$/.exec(value || '');
  if (!match) return undefined;
  const first = Number(match[1]);
  const second = Number(match[2] || match[1]);
  if (!Number.isSafeInteger(first) || !Number.isSafeInteger(second) ||
      first < 1 || second < 1) {
    return undefined;
  }
  return {
    anchor: first,
    start: Math.min(first, second),
    end: Math.max(first, second),
  };
}

export function formatLineRange(range) {
  if (!range) return undefined;
  return range.start === range.end
    ? String(range.start)
    : `${range.start}-${range.end}`;
}

export function clampLineRange(range, lineCount) {
  if (!range || lineCount < 1) return undefined;
  const clamp = (line) => Math.max(1, Math.min(line, lineCount));
  const anchor = clamp(range.anchor);
  const start = clamp(range.start);
  const end = clamp(range.end);
  return {
    anchor,
    start: Math.min(start, end),
    end: Math.max(start, end),
  };
}

export function nextLineRange(current, line, extend) {
  if (!extend || !current) {
    return {anchor: line, start: line, end: line};
  }
  return {
    anchor: current.anchor,
    start: Math.min(current.anchor, line),
    end: Math.max(current.anchor, line),
  };
}

export function serializeEditorState({
  source,
  content,
  pane,
  lines,
  normal,
  strict,
} = {}) {
  const hasContent = content !== undefined;
  const hasLines = Boolean(pane && lines);
  const hasNormal = normal === true && strict !== true;
  const hasStrict = strict === true;
  if (!hasContent && !hasLines && !hasNormal && !hasStrict) return '';

  if (hasContent && !sourceNames.has(source)) {
    throw new Error(`invalid editor source: ${source}`);
  }
  if (hasLines && !paneNames.has(pane)) {
    throw new Error(`invalid editor pane: ${pane}`);
  }
  if (normal !== undefined && typeof normal !== 'boolean') {
    throw new Error(`invalid JSON Schema normal state: ${normal}`);
  }
  if (strict !== undefined && typeof strict !== 'boolean') {
    throw new Error(`invalid YAMLSchema strict state: ${strict}`);
  }

  const parameters = new URLSearchParams();
  parameters.set('v', stateVersion);
  if (hasContent) {
    parameters.set('s', source);
    parameters.set('z', encodeContent(content));
  }
  if (hasNormal) parameters.set('n', '1');
  if (hasStrict) parameters.set('t', '1');
  if (hasLines) {
    parameters.set('p', pane);
    parameters.set('l', formatLineRange(lines));
  }
  return `#${parameters}`;
}

export function parseEditorState(hash) {
  if (!hash || hash === '#') return {ok: true, state: {}};
  try {
    const parameters = new URLSearchParams(hash.replace(/^#/, ''));
    if (parameters.get('v') !== stateVersion) {
      throw new Error('unsupported editor URL version');
    }

    const source = parameters.get('s');
    const encoded = parameters.get('z');
    const normal = parameters.get('n');
    const strict = parameters.get('t');
    const state = {};
    if (source !== null || encoded !== null) {
      if (!sourceNames.has(source) || encoded === null) {
        throw new Error('incomplete editor content state');
      }
      state.source = source;
      state.content = decodeContent(encoded);
    }
    if (normal !== null) {
      if (normal !== '1') {
        throw new Error(`invalid JSON Schema normal state: ${normal}`);
      }
      state.normal = true;
    }
    if (strict !== null) {
      if (strict !== '1') {
        throw new Error(`invalid YAMLSchema strict state: ${strict}`);
      }
      state.strict = true;
    }

    const pane = parameters.get('p');
    const lines = parseLineRange(parameters.get('l'));
    if (paneNames.has(pane) && lines) {
      state.pane = pane;
      state.lines = lines;
    }
    return {ok: true, state};
  } catch (error) {
    return {ok: false, error: error.message, state: {}};
  }
}
