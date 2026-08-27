import { el } from '../lib/dom'
import { site } from '../data/site'

export function renderHeader(): DocumentFragment {
  const navLinks = (variant: 'bar' | 'overlay') =>
    site.nav.map((item, i) =>
      el(
        'a',
        {
          class: `nav-link nav-link--${variant}`,
          href: `#${item.id}`,
          'data-section': item.id,
          style: `--i:${i}`,
        },
        [
          el('span', { class: 'nav-link__en' }, [item.labelEn]),
          el('span', { class: 'nav-link__ja' }, [item.label]),
        ],
      ),
    )

  const header = el('header', { class: 'header', id: 'header' }, [
    el('a', { class: 'header__logo', href: '#top', 'data-section': 'top' }, [
      el('span', { class: 'header__logo-en' }, [site.titleEn]),
      el('span', { class: 'header__logo-ja' }, [site.title]),
    ]),
    el('nav', { class: 'header__nav', 'aria-label': 'メインナビゲーション' }, navLinks('bar')),
    el(
      'button',
      {
        class: 'nav-toggle',
        id: 'nav-toggle',
        type: 'button',
        'aria-expanded': 'false',
        'aria-controls': 'nav-overlay',
        'aria-label': 'メニューを開く',
      },
      [el('span', { class: 'nav-toggle__bars', 'aria-hidden': 'true' }), el('span', { class: 'nav-toggle__label' }, ['MENU'])],
    ),
  ])

  const overlay = el(
    'div',
    { class: 'nav-overlay', id: 'nav-overlay', 'aria-hidden': 'true' },
    [
      el('div', { class: 'nav-overlay__inner' }, [
        el('nav', { class: 'nav-overlay__nav', 'aria-label': 'サイト内メニュー' }, navLinks('overlay')),
        el('p', { class: 'nav-overlay__copy' }, [site.copyright]),
      ]),
    ],
  )

  const f = document.createDocumentFragment()
  f.append(header, overlay)
  return f
}
