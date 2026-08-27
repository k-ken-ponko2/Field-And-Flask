/**
 * Procedural placeholder artwork. The template ships no third-party images:
 * every "key visual" is an SVG generated from a seed and a two-color palette,
 * so a real project can drop in photography without touching layout code.
 */

/** Deterministic 32-bit hash -> [0,1) generator. */
function seeded(seed: string): () => number {
  let h = 2166136261
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return () => {
    h ^= h << 13
    h ^= h >>> 17
    h ^= h << 5
    return ((h >>> 0) % 100000) / 100000
  }
}

export interface PortraitOptions {
  readonly seed: string
  readonly palette: readonly [string, string]
  readonly width?: number
  readonly height?: number
}

/** A silhouette-in-a-spotlight portrait, used for character and album cards. */
export function portraitSvg({
  seed,
  palette,
  width = 600,
  height = 800,
}: PortraitOptions): string {
  const rand = seeded(seed)
  const [dark, accent] = palette
  const id = `kv-${seed.replaceAll(/[^a-z0-9]/gi, '')}`
  const cx = width * (0.4 + rand() * 0.2)
  const headR = width * 0.13
  const headY = height * (0.26 + rand() * 0.04)
  const shoulder = width * (0.24 + rand() * 0.06)

  const rays = Array.from({ length: 7 }, (_, i) => {
    const x = width * (0.05 + rand() * 0.9)
    const w = width * (0.01 + rand() * 0.05)
    return `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="${height}" fill="${accent}" opacity="${(0.03 + rand() * 0.05).toFixed(3)}" data-ray="${i}"/>`
  }).join('')

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="placeholder key visual" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="${id}-bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${dark}"/>
      <stop offset="1" stop-color="#05060c"/>
    </linearGradient>
    <radialGradient id="${id}-glow" cx="50%" cy="34%" r="58%">
      <stop offset="0" stop-color="${accent}" stop-opacity="0.55"/>
      <stop offset="1" stop-color="${accent}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#${id}-bg)"/>
  ${rays}
  <ellipse cx="${(width / 2).toFixed(1)}" cy="${(height * 0.34).toFixed(1)}" rx="${(width * 0.42).toFixed(1)}" ry="${(height * 0.34).toFixed(1)}" fill="url(#${id}-glow)"/>
  <g fill="#05060c" opacity="0.92">
    <circle cx="${cx.toFixed(1)}" cy="${headY.toFixed(1)}" r="${headR.toFixed(1)}"/>
    <path d="M ${(cx - shoulder).toFixed(1)} ${height}
             C ${(cx - shoulder).toFixed(1)} ${(headY + headR * 2.2).toFixed(1)},
               ${(cx - headR).toFixed(1)} ${(headY + headR * 1.1).toFixed(1)},
               ${cx.toFixed(1)} ${(headY + headR * 1.05).toFixed(1)}
             C ${(cx + headR).toFixed(1)} ${(headY + headR * 1.1).toFixed(1)},
               ${(cx + shoulder).toFixed(1)} ${(headY + headR * 2.2).toFixed(1)},
               ${(cx + shoulder).toFixed(1)} ${height} Z"/>
  </g>
  <rect width="${width}" height="${height}" fill="${accent}" opacity="0.06" style="mix-blend-mode:screen"/>
</svg>`
}

/** Wide hero backdrop: horizon line, water, scattered harbour lights. */
export function heroSvg(palette: readonly [string, string] = ['#0a1830', '#4dd6ff']): string {
  const rand = seeded('hero')
  const [dark, accent] = palette
  const lights = Array.from({ length: 46 }, () => {
    const x = (rand() * 1600).toFixed(1)
    const y = (240 + rand() * 220).toFixed(1)
    const r = (0.8 + rand() * 2.4).toFixed(2)
    return `<circle cx="${x}" cy="${y}" r="${r}" fill="${accent}" opacity="${(0.25 + rand() * 0.7).toFixed(2)}"/>`
  }).join('')
  const reflections = Array.from({ length: 30 }, () => {
    const x = (rand() * 1600).toFixed(1)
    const y = (500 + rand() * 340).toFixed(1)
    const w = (1 + rand() * 3).toFixed(1)
    const h = (10 + rand() * 70).toFixed(1)
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${accent}" opacity="${(0.05 + rand() * 0.18).toFixed(2)}"/>`
  }).join('')

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" role="img" aria-label="placeholder hero visual" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="hero-sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#02030a"/>
      <stop offset="0.55" stop-color="${dark}"/>
      <stop offset="1" stop-color="#02030a"/>
    </linearGradient>
    <radialGradient id="hero-moon" cx="72%" cy="22%" r="26%">
      <stop offset="0" stop-color="${accent}" stop-opacity="0.5"/>
      <stop offset="1" stop-color="${accent}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1600" height="900" fill="url(#hero-sky)"/>
  <rect width="1600" height="900" fill="url(#hero-moon)"/>
  <circle cx="1152" cy="198" r="58" fill="${accent}" opacity="0.16"/>
  ${lights}
  <rect y="470" width="1600" height="430" fill="#02030a" opacity="0.55"/>
  ${reflections}
</svg>`
}

/** Data-URI wrapper so an SVG string can be used as a CSS background. */
export function svgToDataUri(svg: string): string {
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`
}
