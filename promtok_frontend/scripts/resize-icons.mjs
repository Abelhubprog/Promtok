import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { promises as fs } from 'node:fs'
import sharp from 'sharp'
import pngToIco from 'png-to-ico'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const publicDir = join(__dirname, '..', 'public')
const source = join(publicDir, 'icon_original.PNG')

const targets = [
  { file: 'apple-touch-icon.png', w: 180, h: 180 },
  { file: 'favicon-16x16.png', w: 16, h: 16 },
  { file: 'favicon-32x32.png', w: 32, h: 32 },
  { file: 'favicon-48x48.png', w: 48, h: 48 },
  { file: 'icon-72x72.png', w: 72, h: 72 },
  { file: 'icon-96x96.png', w: 96, h: 96 },
  { file: 'icon-128x128.png', w: 128, h: 128 },
  { file: 'icon-144x144.png', w: 144, h: 144 },
  { file: 'icon-192x192.png', w: 192, h: 192 },
  { file: 'icon-256x256.png', w: 256, h: 256 },
  { file: 'icon-512x512.png', w: 512, h: 512 },
  // Keep vite.svg as-is
]

const pngOptions = { compressionLevel: 9, adaptiveFiltering: true }

async function ensureReadable(path) {
  try { await fs.access(path) } catch (e) {
    throw new Error(`Source not found: ${path}`)
  }
}

async function resizePng(target) {
  const outPath = join(publicDir, target.file)
  await sharp(source)
    .resize(target.w, target.h, { fit: 'cover' })
    .png(pngOptions)
    .toFile(outPath)
}

async function makeIco() {
  // Build multi-size ICO from 16, 32, 48 PNG buffers
  const sizes = [16, 32, 48]
  const bufs = await Promise.all(
    sizes.map(sz => sharp(source).resize(sz, sz, { fit: 'cover' }).png().toBuffer())
  )
  const icoBuf = await pngToIco(bufs)
  await fs.writeFile(join(publicDir, 'favicon.ico'), icoBuf)
}

async function maybeReplaceIconDark() {
  // Preserve original dimensions of icon_dark.png but replace content
  const darkPath = join(publicDir, 'icon_dark.png')
  try {
    const meta = await sharp(darkPath).metadata()
    if (!meta.width || !meta.height) throw new Error('No size')
    await sharp(source)
      .resize(meta.width, meta.height, { fit: 'cover' })
      .png(pngOptions)
      .toFile(darkPath)
  } catch {
    // If missing or unreadable, create a 773x773 default (matches repo)
    await sharp(source)
      .resize(773, 773, { fit: 'cover' })
      .png(pngOptions)
      .toFile(darkPath)
  }
}

async function main() {
  await ensureReadable(source)
  await Promise.all(targets.map(resizePng))
  await makeIco()
  await maybeReplaceIconDark()
  console.log('Icons refreshed from icon_original.PNG')
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
