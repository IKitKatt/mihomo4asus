import { readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const outputFile = fileURLToPath(new URL('../../www/app.js', import.meta.url))
const source = await readFile(outputFile, 'utf8')
const escaped = source.replaceAll('<%', '\\x3C%')

if (escaped.includes('<%')) {
  throw new Error('Unable to escape Merlin ASP template markers in app.js')
}

await writeFile(outputFile, escaped, 'utf8')
