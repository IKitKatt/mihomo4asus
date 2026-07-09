<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { basicSetup, EditorView } from 'codemirror'
import { yaml } from '@codemirror/lang-yaml'
import { indentLess, indentMore } from '@codemirror/commands'
import { keymap } from '@codemirror/view'
import { syntaxHighlighting, HighlightStyle } from '@codemirror/language'
import { tags } from '@lezer/highlight'

const props = defineProps<{
  modelValue: string
  readonly?: boolean
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: string): void
}>()

const host = ref<HTMLDivElement | null>(null)
let view: EditorView | null = null
let updatingFromParent = false

const theme = EditorView.theme({
  '&': {
    height: '100%',
    fontSize: '12px',
    borderRadius: '4px',
    backgroundColor: '#1f272a',
    color: '#d7dedf'
  },
  '.cm-scroller': {
    fontFamily: '"Cascadia Mono", "SFMono-Regular", Consolas, monospace',
    lineHeight: '1.45'
  },
  '.cm-content': {
    minHeight: '100%',
    caretColor: '#f4f6f6'
  },
  '.cm-gutters': {
    border: '0',
    borderRight: '1px solid #3a494e',
    backgroundColor: '#273337',
    color: '#819094'
  },
  '.cm-lineNumbers .cm-gutterElement': {
    minWidth: '38px',
    padding: '0 8px 0 6px',
    color: '#819094'
  },
  '.cm-activeLineGutter': {
    backgroundColor: '#324044',
    color: '#c8d0d2'
  },
  '.cm-activeLine': {
    backgroundColor: '#263236'
  },
  '.cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection': {
    backgroundColor: '#46575b !important'
  },
  '.cm-cursor, .cm-dropCursor': {
    borderLeftColor: '#f4f6f6'
  },
  '.cm-matchingBracket': {
    backgroundColor: '#485a5f',
    outline: '0'
  }
}, { dark: true })

const highlighting = HighlightStyle.define([
  { tag: tags.keyword, color: '#d8b255' },
  { tag: tags.bool, color: '#76c7e7' },
  { tag: tags.null, color: '#c7a8d9' },
  { tag: tags.propertyName, color: '#e0c46c' },
  { tag: tags.string, color: '#bddb9a' },
  { tag: tags.number, color: '#dfa96a' },
  { tag: tags.comment, color: '#77878b', fontStyle: 'italic' },
  { tag: tags.punctuation, color: '#bdc8ca' },
  { tag: tags.atom, color: '#c7a8d9' }
])

function selectedLineNumbers() {
  if (!view) return []
  const numbers = new Set<number>()
  for (const range of view.state.selection.ranges) {
    let fromLine = view.state.doc.lineAt(range.from)
    let toLine = view.state.doc.lineAt(range.to)
    if (range.to === toLine.from && range.to > range.from) {
      toLine = view.state.doc.lineAt(range.to - 1)
    }
    for (let line = fromLine.number; line <= toLine.number; line += 1) {
      numbers.add(line)
    }
  }
  return Array.from(numbers).sort((a, b) => a - b)
}

function replaceSelectedLines(transform: (line: string) => string) {
  if (!view) return
  const changes = selectedLineNumbers().map((lineNumber) => {
    const line = view!.state.doc.line(lineNumber)
    return {
      from: line.from,
      to: line.to,
      insert: transform(line.text)
    }
  }).filter((change) => view!.state.doc.sliceString(change.from, change.to) !== change.insert)

  if (changes.length > 0) {
    view.dispatch({ changes })
    view.focus()
  }
}

function toggleLineComment() {
  if (!view) return
  const lines = selectedLineNumbers().map((lineNumber) => view!.state.doc.line(lineNumber).text)
  const shouldUncomment = lines.length > 0 && lines.every((line) => line.trim() === '' || /^[ \t]*# ?/.test(line))
  replaceSelectedLines((line) => {
    if (line.trim() === '') return line
    if (shouldUncomment) return line.replace(/^([ \t]*)# ?/, '$1')
    return line.replace(/^([ \t]*)/, '$1# ')
  })
}

function indentSelection() {
  replaceSelectedLines((line) => `  ${line}`)
}

function outdentSelection() {
  replaceSelectedLines((line) => line.replace(/^ {1,2}/, ''))
}

onMounted(() => {
  if (!host.value) return
  view = new EditorView({
    parent: host.value,
    doc: props.modelValue,
    extensions: [
      basicSetup,
      yaml(),
      keymap.of([
        {
          key: 'Ctrl-/',
          run: () => {
            toggleLineComment()
            return true
          }
        },
        {
          key: 'Mod-/',
          run: () => {
            toggleLineComment()
            return true
          }
        },
        {
          key: 'Ctrl-k',
          run: () => {
            toggleLineComment()
            return true
          }
        },
        {
          key: 'Tab',
          run: indentMore
        },
        {
          key: 'Shift-Tab',
          run: indentLess
        }
      ]),
      EditorView.lineWrapping,
      EditorView.editable.of(!props.readonly),
      theme,
      syntaxHighlighting(highlighting),
      EditorView.updateListener.of((update) => {
        if (update.docChanged && !updatingFromParent) {
          emit('update:modelValue', update.state.doc.toString())
        }
      })
    ]
  })
})

watch(() => props.modelValue, (value) => {
  if (!view || value === view.state.doc.toString()) return
  updatingFromParent = true
  view.dispatch({
    changes: {
      from: 0,
      to: view.state.doc.length,
      insert: value
    }
  })
  updatingFromParent = false
})

onBeforeUnmount(() => {
  view?.destroy()
  view = null
})

defineExpose({
  toggleLineComment,
  indentSelection,
  outdentSelection
})
</script>

<template>
  <div ref="host" class="yaml-editor"></div>
</template>
