<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { basicSetup, EditorView } from 'codemirror'
import { yaml } from '@codemirror/lang-yaml'
import { indentLess, indentMore } from '@codemirror/commands'
import { keymap } from '@codemirror/view'

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
    minHeight: '520px',
    fontSize: '12px',
    borderRadius: '6px'
  },
  '.cm-scroller': {
    fontFamily: '"Cascadia Mono", "SFMono-Regular", Consolas, monospace',
    lineHeight: '1.45'
  },
  '.cm-content': {
    minHeight: '520px'
  },
  '.cm-gutters': {
    borderRadius: '6px 0 0 6px'
  }
})

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
