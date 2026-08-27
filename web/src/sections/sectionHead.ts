import { el } from '../lib/dom'

/** Shared section heading: big English label over a small Japanese one. */
export function sectionHead(en: string, ja: string): HTMLElement {
  return el('div', { class: 'section-head', 'data-reveal': '' }, [
    el('h2', { class: 'section-head__en' }, [en]),
    el('p', { class: 'section-head__ja' }, [ja]),
  ])
}
