import {syntaxTree} from '@codemirror/language';

function children(node, name) {
  const result = [];
  for (let child = node.firstChild; child; child = child.nextSibling) {
    if (!name || child.name === name) result.push(child);
  }
  return result;
}

function child(node, name) {
  return children(node, name)[0];
}

function jsonPropertyName(state, property) {
  const name = child(property, 'PropertyName');
  if (!name) return undefined;
  try {
    return JSON.parse(state.doc.sliceString(name.from, name.to));
  } catch {
    return undefined;
  }
}

function jsonPropertyValue(property) {
  const name = child(property, 'PropertyName');
  if (!name) return undefined;
  for (let current = name.nextSibling; current; current = current.nextSibling) {
    if (current.name !== ':') return current;
  }
  return undefined;
}

function jsonSections(state) {
  const root = syntaxTree(state).topNode;
  const object = child(root, 'Object');
  if (!object) return [];
  const groups = new Map();
  for (const property of children(object, 'Property')) {
    const name = jsonPropertyName(state, property);
    if (name !== '$defs' && name !== 'definitions' &&
        name !== 'properties') continue;
    const value = jsonPropertyValue(property);
    if (value?.name === 'Object') groups.set(name, value);
  }
  const result = [];
  for (const [group, prefix] of [
    ['$defs', 'defs'],
    ['definitions', 'defs'],
    ['properties', 'properties'],
  ]) {
    const objectValue = groups.get(group);
    if (!objectValue) continue;
    for (const property of children(objectValue, 'Property')) {
      const name = jsonPropertyName(state, property);
      if (name === undefined) continue;
      result.push({
        id: `${prefix}/${name}`,
        from: property.from,
        to: property.to,
      });
    }
  }
  return result.sort((left, right) => left.from - right.from);
}

function yamlKey(state, pair) {
  const key = child(pair, 'Key');
  if (!key) return undefined;
  const value = state.doc.sliceString(key.from, key.to).trim();
  if (value.startsWith('"')) {
    try {
      return JSON.parse(value);
    } catch {
      return undefined;
    }
  }
  if (value.startsWith("'") && value.endsWith("'")) {
    return value.slice(1, -1).replaceAll("''", "'");
  }
  return value;
}

function yamlMapping(pair) {
  for (let current = pair.firstChild; current;
    current = current.nextSibling) {
    if (current.name === 'BlockMapping') return current;
  }
  return undefined;
}

function yamlPropertySection(state, pair) {
  let name = yamlKey(state, pair);
  if (!name || name.startsWith('.')) return undefined;
  if (name.startsWith('+')) {
    if (name === '+Str') return undefined;
    return {id: `defs/${name.slice(1)}`, from: pair.from, to: pair.to};
  }
  if (name.endsWith('?')) name = name.slice(0, -1);
  return {id: `properties/${name}`, from: pair.from, to: pair.to};
}

function yamlSections(state) {
  const root = syntaxTree(state).topNode;
  const documentNode = child(root, 'Document');
  const mapping = documentNode && child(documentNode, 'BlockMapping');
  if (!mapping) return [];
  const result = [];
  for (const pair of children(mapping, 'Pair')) {
    const name = yamlKey(state, pair);
    if (name === '.root') {
      const rootMapping = yamlMapping(pair);
      if (!rootMapping) continue;
      for (const rootPair of children(rootMapping, 'Pair')) {
        const section = yamlPropertySection(state, rootPair);
        if (section) result.push(section);
      }
      continue;
    }
    const section = yamlPropertySection(state, pair);
    if (section) result.push(section);
  }
  return result.sort((left, right) => left.from - right.from);
}

export function schemaSections(state, format) {
  return format === 'json' ? jsonSections(state) : yamlSections(state);
}
