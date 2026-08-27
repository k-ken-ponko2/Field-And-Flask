import { el, splitChars } from '../lib/dom'
import { site } from '../data/site'
import { heroSvg, svgToDataUri } from '../lib/keyvisual'

export function renderHero(): HTMLElement {
  const marqueeText = `${site.titleEn} — ${site.tagline} — `
  const marquee = el('div', { class: 'marquee', 'aria-hidden': 'true' }, [
    el('div', { class: 'marquee__track' }, [
      el('span', {}, [marqueeText.repeat(4)]),
      el('span', {}, [marqueeText.repeat(4)]),
    ]),
  ])

  return el('section', { class: 'hero', id: 'top', 'data-nav-target': '' }, [
    el('div', {
      class: 'hero__visual',
      style: `background-image:${svgToDataUri(heroSvg())}`,
      'aria-hidden': 'true',
    }),
    el('div', { class: 'hero__scrim', 'aria-hidden': 'true' }),
    el('div', { class: 'hero__inner' }, [
      el('p', { class: 'hero__eyebrow' }, [site.titleEn]),
      el(
        'h1',
        { class: 'hero__title', 'aria-label': site.catchcopy.join('') },
        site.catchcopy.map((line, li) =>
          el('span', { class: 'hero__line', style: `--line:${li}` }, [splitChars(line)]),
        ),
      ),
      el('p', { class: 'hero__lead' }, [site.description]),
    ]),
    marquee,
    el('a', { class: 'hero__scroll', href: '#news', 'data-section': 'news' }, [
      el('span', {}, ['SCROLL']),
      el('span', { class: 'hero__scroll-line', 'aria-hidden': 'true' }),
    ]),
  ])
}
