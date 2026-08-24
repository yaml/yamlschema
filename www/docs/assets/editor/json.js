export function normalizeJson(text) {
  let normalized = '';
  let inString = false;
  let escaped = false;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (inString) {
      normalized += character;
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === '"') inString = false;
      continue;
    }

    if (character === '"') {
      inString = true;
      normalized += character;
      continue;
    }

    if (character === ',') {
      let next = index + 1;
      while (next < text.length && /\s/.test(text[next])) next += 1;
      if (text[next] === '}' || text[next] === ']') continue;
    }

    normalized += character;
  }

  JSON.parse(normalized);
  return normalized;
}
