(function installUnifiedDiff(global) {
  'use strict';

  const negativeInfinity = Number.NEGATIVE_INFINITY;

  function lines(text) {
    const normalized = text.replace(/\r\n/g, '\n').replace(/\n$/, '');
    return normalized === '' ? [] : normalized.split('\n');
  }

  function valueAt(frontier, diagonal) {
    return frontier.has(diagonal)
      ? frontier.get(diagonal)
      : negativeInfinity;
  }

  function backtrack(trace, before, after) {
    const edits = [];
    let x = before.length;
    let y = after.length;

    for (let depth = trace.length - 1; depth >= 0; depth -= 1) {
      const frontier = trace[depth];
      const diagonal = x - y;
      const down = diagonal === -depth || (
        diagonal !== depth &&
        valueAt(frontier, diagonal - 1) <
          valueAt(frontier, diagonal + 1)
      );
      const previousDiagonal = down ? diagonal + 1 : diagonal - 1;
      const previousX = valueAt(frontier, previousDiagonal);
      const previousY = previousX - previousDiagonal;

      while (x > previousX && y > previousY) {
        edits.push({type: 'equal', line: before[x - 1]});
        x -= 1;
        y -= 1;
      }

      if (depth === 0) break;
      if (x === previousX) {
        edits.push({type: 'insert', line: after[y - 1]});
        y -= 1;
      } else {
        edits.push({type: 'delete', line: before[x - 1]});
        x -= 1;
      }
    }

    return edits.reverse();
  }

  function editScript(before, after) {
    const maximum = before.length + after.length;
    const trace = [];
    const frontier = new Map([[1, 0]]);

    for (let depth = 0; depth <= maximum; depth += 1) {
      trace.push(new Map(frontier));
      for (
        let diagonal = -depth;
        diagonal <= depth;
        diagonal += 2
      ) {
        const down = diagonal === -depth || (
          diagonal !== depth &&
          valueAt(frontier, diagonal - 1) <
            valueAt(frontier, diagonal + 1)
        );
        let x = down
          ? valueAt(frontier, diagonal + 1)
          : valueAt(frontier, diagonal - 1) + 1;
        let y = x - diagonal;

        while (
          x < before.length &&
          y < after.length &&
          before[x] === after[y]
        ) {
          x += 1;
          y += 1;
        }
        frontier.set(diagonal, x);

        if (x >= before.length && y >= after.length) {
          return backtrack(trace, before, after);
        }
      }
    }

    throw new Error('Unable to generate unified diff');
  }

  function hunkRanges(edits, context) {
    const ranges = [];
    for (let index = 0; index < edits.length; index += 1) {
      if (edits[index].type === 'equal') continue;
      const start = Math.max(0, index - context);
      const end = Math.min(edits.length, index + context + 1);
      const previous = ranges[ranges.length - 1];
      if (previous && start <= previous.end) {
        previous.end = Math.max(previous.end, end);
      } else {
        ranges.push({start, end});
      }
    }
    return ranges;
  }

  function countLines(edits, end, omittedType) {
    let count = 0;
    for (let index = 0; index < end; index += 1) {
      if (edits[index].type !== omittedType) count += 1;
    }
    return count;
  }

  function rangeText(start, count) {
    return count === 1 ? `${start}` : `${start},${count}`;
  }

  function hunkHeader(edits, start, end) {
    const oldBefore = countLines(edits, start, 'insert');
    const newBefore = countLines(edits, start, 'delete');
    const oldCount = countLines(edits.slice(start, end), end - start,
      'insert');
    const newCount = countLines(edits.slice(start, end), end - start,
      'delete');
    const oldStart = oldCount === 0 ? oldBefore : oldBefore + 1;
    const newStart = newCount === 0 ? newBefore : newBefore + 1;
    return `@@ -${rangeText(oldStart, oldCount)} ` +
      `+${rangeText(newStart, newCount)} @@`;
  }

  function createUnifiedDiff(original, roundtripped, context = 3) {
    const before = lines(original);
    const after = lines(roundtripped);
    const edits = editScript(before, after);
    const ranges = hunkRanges(edits, context);
    if (ranges.length === 0) return '';

    const output = ['--- original', '+++ roundtrip'];
    for (const {start, end} of ranges) {
      output.push(hunkHeader(edits, start, end));
      for (const edit of edits.slice(start, end)) {
        const prefix = {
          delete: '-',
          equal: ' ',
          insert: '+',
        }[edit.type];
        output.push(prefix + edit.line);
      }
    }
    return `${output.join('\n')}\n`;
  }

  global.createUnifiedDiff = createUnifiedDiff;
})(globalThis);
