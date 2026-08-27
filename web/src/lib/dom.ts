/** Minimal DOM helpers. Kept dependency-free on purpose. */

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Record<string, string> = {},
  children: readonly (Node | string)[] = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag)
  for (const [key, value] of Object.entries(attrs)) {
    if (key === 'class') node.className = value
    else node.setAttribute(key, value)
  }
  for (const child of children) {
    node.append(typeof child === 'string' ? document.createTextNode(child) : child)
  }
  return node
}

export function frag(children: readonly (Node | string)[]): DocumentFragment {
  const f = document.createDocumentFragment()
  for (const child of children) {
    f.append(typeof child === 'string' ? document.createTextNode(child) : child)
  }
  return f
}

export function must<T extends Element>(selector: string, root: ParentNode = document): T {
  const found = root.querySelector<T>(selector)
  if (!found) throw new Error(`Element not found: ${selector}`)
  return found
}

/** Splits a string into per-character spans so CSS can stagger them. */
export function splitChars(text: string, className = 'char'): DocumentFragment {
  return frag(
    [...text].map((ch, i) =>
      el('span', { class: className, style: `--i:${i}`, 'aria-hidden': 'true' }, [
        ch === ' ' ? ' ' : ch,
      ]),
    ),
  )
}

/** "2026-08-24" -> "2026.08.24" */
export function formatDate(iso: string): string {
  return iso.replaceAll('-', '.')
}

export function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}
