import { el } from '../lib/dom'
import { snsLinks } from '../data/media'
import { site } from '../data/site'
import { sectionHead } from './sectionHead'

export function renderSns(): HTMLElement {
  return el('section', { class: 'section section--sns', id: 'sns', 'data-nav-target': '' }, [
    el('div', { class: 'container' }, [
      sectionHead('SNS', '公式SNS'),
      el(
        'div',
        { class: 'sns-grid', 'data-reveal': '' },
        snsLinks.map((link, i) =>
          el(
            'a',
            {
              class: 'sns-card',
              href: link.href,
              style: `--i:${i}`,
              rel: 'noopener noreferrer',
            },
            [
              el('span', { class: 'sns-card__label' }, [link.label]),
              el('span', { class: 'sns-card__handle' }, [link.handle]),
              el('span', { class: 'sns-card__arrow', 'aria-hidden': 'true' }, ['↗']),
            ],
          ),
        ),
      ),
    ]),
  ])
}

export function renderFooter(): HTMLElement {
  return el('footer', { class: 'footer' }, [
    el('div', { class: 'container footer__inner' }, [
      el('p', { class: 'footer__logo' }, [site.titleEn]),
      el('nav', { class: 'footer__nav', 'aria-label': 'フッターメニュー' }, [
        el('a', { href: '#top', 'data-section': 'top' }, ['ページ上部へ']),
        el('a', { href: '#about', 'data-section': 'about' }, ['この物語について']),
        el('a', { href: '#news', 'data-section': 'news' }, ['ニュース']),
      ]),
      el('small', { class: 'footer__copy' }, [site.copyright]),
    ]),
  ])
}
