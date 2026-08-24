import {
  HighlightStyle,
  bracketMatching,
  foldGutter,
  foldKeymap,
  indentOnInput,
  syntaxHighlighting,
} from '@codemirror/language';
import {highlightSelectionMatches, searchKeymap} from '@codemirror/search';
import {
  Compartment,
  EditorState,
  RangeSet,
  StateEffect,
  StateField,
  Transaction,
} from '@codemirror/state';
import {
  Decoration,
  EditorView,
  GutterMarker,
  gutterLineClass,
  highlightActiveLine,
  highlightActiveLineGutter,
  keymap,
  lineNumbers,
} from '@codemirror/view';
import {minimalSetup} from 'codemirror';
import {tags} from '@lezer/highlight';

import {clampLineRange, nextLineRange} from './url-state.js';
import {schemaSections} from './schema-sections.js';

const setLinkedLines = StateEffect.define();
const schemaHighlightStyle = HighlightStyle.define([
  {tag: [tags.propertyName, tags.attributeName], color: 'var(--editor-key)'},
  {
    tag: [tags.string, tags.special(tags.string)],
    color: 'var(--editor-string)',
  },
  {tag: [tags.number, tags.bool, tags.null], color: 'var(--editor-value)'},
  {tag: [tags.comment, tags.lineComment], color: 'var(--editor-comment)'},
  {
    tag: [tags.punctuation, tags.separator],
    color: 'var(--editor-punctuation)',
  },
]);
const linkedNumberMarker = new class extends GutterMarker {
  elementClass = 'cm-linked-line-number';
}();

function mapLineRange(range, transaction) {
  if (!range || !transaction.docChanged) return range;
  const oldDocument = transaction.startState.doc;
  const newDocument = transaction.newDoc;
  const mapLine = (number) => {
    const position = oldDocument.line(number).from;
    return newDocument.lineAt(transaction.changes.mapPos(position)).number;
  };
  const anchor = mapLine(range.anchor);
  const start = mapLine(range.start);
  const end = mapLine(range.end);
  return {
    anchor,
    start: Math.min(start, end),
    end: Math.max(start, end),
  };
}

const linkedLinesField = StateField.define({
  create() {
    return undefined;
  },
  update(range, transaction) {
    let next = mapLineRange(range, transaction);
    for (const effect of transaction.effects) {
      if (effect.is(setLinkedLines)) next = effect.value;
    }
    return next;
  },
});

const linkedLineDecorations = EditorView.decorations.compute(
  [linkedLinesField],
  (state) => {
    const range = state.field(linkedLinesField);
    if (!range) return Decoration.none;
    const decorations = [];
    for (let number = range.start; number <= range.end; number += 1) {
      decorations.push(Decoration.line({class: 'cm-linked-line'}).range(
        state.doc.line(number).from,
      ));
    }
    return Decoration.set(decorations);
  },
);

const linkedLineNumbers = gutterLineClass.compute(
  [linkedLinesField],
  (state) => {
    const range = state.field(linkedLinesField);
    if (!range) return RangeSet.empty;
    const markers = [];
    for (let number = range.start; number <= range.end; number += 1) {
      markers.push(linkedNumberMarker.range(state.doc.line(number).from));
    }
    return RangeSet.of(markers, true);
  },
);

export class CodeEditor {
  constructor(mount, {
    language,
    ariaLabel,
    onChange,
    onFocus,
    onLinkedLines,
    onScroll = () => {},
  }) {
    this.mount = mount;
    this.onChange = onChange;
    this.onFocus = onFocus;
    this.onLinkedLines = onLinkedLines;
    this.onScroll = onScroll;
    this.settingValue = false;
    this.linkedLineScrollFrame = undefined;
    this.readOnlyCompartment = new Compartment();

    const lineNumberExtension = lineNumbers({
      domEventHandlers: {
        mousedown: (view, line, event) => {
          if (event.button !== 0) return false;
          const number = view.state.doc.lineAt(line.from).number;
          const current = view.state.field(linkedLinesField);
          const range = nextLineRange(current, number, event.shiftKey);
          view.dispatch({effects: setLinkedLines.of(range)});
          this.onLinkedLines(range);
          view.focus();
          event.preventDefault();
          return true;
        },
      },
    });

    const clearLinkedLines = (view) => {
      if (!view.state.field(linkedLinesField)) return false;
      view.dispatch({effects: setLinkedLines.of(undefined)});
      this.onLinkedLines(undefined);
      return true;
    };

    this.view = new EditorView({
      parent: mount,
      extensions: [
        minimalSetup,
        language,
        syntaxHighlighting(schemaHighlightStyle),
        lineNumberExtension,
        linkedLinesField,
        linkedLineDecorations,
        linkedLineNumbers,
        foldGutter(),
        indentOnInput(),
        bracketMatching(),
        highlightActiveLine(),
        highlightActiveLineGutter(),
        highlightSelectionMatches(),
        EditorView.lineWrapping,
        EditorView.contentAttributes.of({
          'aria-label': ariaLabel,
          spellcheck: 'false',
        }),
        keymap.of([
          {
            key: 'Escape',
            run: clearLinkedLines,
          },
          ...searchKeymap,
          ...foldKeymap,
        ]),
        EditorView.domEventHandlers({
          focus: () => {
            this.onFocus();
            return false;
          },
          mousedown: () => {
            clearLinkedLines(this.view);
            return false;
          },
        }),
        EditorView.updateListener.of((update) => {
          if (update.docChanged && !this.settingValue) {
            this.onChange();
            const before = update.startState.field(linkedLinesField);
            const after = update.state.field(linkedLinesField);
            if (JSON.stringify(before) !== JSON.stringify(after)) {
              this.onLinkedLines(after);
            }
          }
        }),
        this.readOnlyCompartment.of([
          EditorState.readOnly.of(false),
          EditorView.editable.of(true),
        ]),
      ],
    });
    this.view.scrollDOM.addEventListener('scroll', () => {
      this.onScroll();
    }, {passive: true});
  }

  get value() {
    return this.view.state.doc.toString();
  }

  get classList() {
    return this.mount.classList;
  }

  setValue(value) {
    if (value === this.value) return;
    this.settingValue = true;
    this.view.dispatch({
      changes: {from: 0, to: this.view.state.doc.length, insert: value},
      effects: setLinkedLines.of(undefined),
      annotations: Transaction.addToHistory.of(false),
    });
    this.settingValue = false;
  }

  setReadOnly(readOnly) {
    this.view.dispatch({
      effects: this.readOnlyCompartment.reconfigure([
        EditorState.readOnly.of(readOnly),
        EditorView.editable.of(!readOnly),
        EditorView.contentAttributes.of(readOnly ? {tabindex: '0'} : {}),
      ]),
    });
    this.mount.classList.toggle('readonly', readOnly);
  }

  setLinkedLines(range, scroll = false) {
    const clamped = clampLineRange(range, this.view.state.doc.lines);
    this.view.dispatch({effects: setLinkedLines.of(clamped)});
    if (scroll && clamped) this.scrollToLinkedLines(clamped);
    return clamped;
  }

  scrollToLinkedLines(range) {
    const scroll = () => {
      const line = Math.min(range.start, this.view.state.doc.lines);
      const position = this.view.state.doc.line(line).from;
      this.view.dispatch({
        effects: EditorView.scrollIntoView(position, {y: 'start'}),
      });
    };
    scroll();
    cancelAnimationFrame(this.linkedLineScrollFrame);
    this.linkedLineScrollFrame = requestAnimationFrame(scroll);
  }

  clearLinkedLines() {
    this.view.dispatch({effects: setLinkedLines.of(undefined)});
  }

  schemaLocation(format) {
    const sections = schemaSections(this.view.state, format);
    const top = this.view.scrollDOM.scrollTop;
    let index = -1;
    for (let current = 0; current < sections.length; current += 1) {
      if (this.view.lineBlockAt(sections[current].from).top > top + 1) break;
      index = current;
    }
    if (index < 0) return undefined;
    const section = sections[index];
    const start = this.view.lineBlockAt(section.from).top;
    const next = sections[index + 1];
    const end = next
      ? this.view.lineBlockAt(next.from).top
      : this.view.lineBlockAt(section.to).bottom;
    const progress = end > start
      ? Math.max(0, Math.min(1, (top - start) / (end - start)))
      : 0;
    return {id: section.id, progress};
  }

  scrollToSchemaLocation(location, format) {
    if (!location) return false;
    const sections = schemaSections(this.view.state, format);
    const index = sections.findIndex((section) => section.id === location.id);
    if (index < 0) return false;
    const section = sections[index];
    const start = this.view.lineBlockAt(section.from).top;
    const next = sections[index + 1];
    const end = next
      ? this.view.lineBlockAt(next.from).top
      : this.view.lineBlockAt(section.to).bottom;
    const maximum = Math.max(0,
      this.view.scrollDOM.scrollHeight - this.view.scrollDOM.clientHeight);
    const top = Math.max(0, Math.min(maximum,
      start + (end - start) * location.progress));
    this.view.scrollDOM.scrollTop = top;
    return true;
  }
}
