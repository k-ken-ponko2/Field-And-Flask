import { el, formatDate } from '../lib/dom'
import { news } from '../data/news'
import type { NewsCategory } from '../types'
import { sectionHead } from './sectionHead'

const FILTERS: readonly { id: NewsCategory | 'all'; label: string }[] = [
  { id: 'all', label: 'ALL' },
  { id: 'news', label: 'NEWS' },
  { id: 'goods', label: 'GOODS' },
  { id: 'event', label: 'EVENT' },
  { id: 'media', label: 'MEDIA' },
]

export function renderNews(): HTMLElement {
  const list = el('ul', { class: 'news-list' })

  const paint = (filter: NewsCategory | 'all') => {
    const items = filter === 'all' ? news : news.filter((n) => n.category === filter)
    list.replaceChildren(
      ...items.map((item, i) =>
        el('li', { class: 'news-item', style: `--i:${i}` }, [
          el('a', { class: 'news-item__link', href: item.href }, [
            el('time', { class: 'news-item__date', datetime: item.date }, [
              formatDate(item.date),
            ]),
            el('span', { class: `news-item__tag is-${item.category}` }, [
              item.category.toUpperCase(),
            ]),
            el('span', { class: 'news-item__title' }, [
              item.title,
              ...(item.isNew ? [el('span', { class: 'news-item__new' }, ['NEW'])] : []),
            ]),
            el('span', { class: 'news-item__arrow', 'aria-hidden': 'true' }, ['→']),
          ]),
        ]),
      ),
    )
    if (items.length === 0) {
      list.append(el('li', { class: 'news-empty' }, ['該当するお知らせはありません。']))
    }
  }

  const tabs = el(
    'div',
    { class: 'news-tabs', role: 'tablist', 'aria-label': 'ニュースの絞り込み' },
    FILTERS.map((f, i) => {
      const button = el(
        'button',
        {
          class: 'news-tab',
          type: 'button',
          role: 'tab',
          'aria-selected': String(i === 0),
        },
        [f.label],
      )
      button.addEventListener('click', () => {
        for (const other of tabs.querySelectorAll('.news-tab')) {
          other.setAttribute('aria-selected', String(other === button))
        }
        paint(f.id)
      })
      return button
    }),
  )

  paint('all')

  return el('section', { class: 'section section--news', id: 'news', 'data-nav-target': '' }, [
    el('div', { class: 'container' }, [
      sectionHead('NEWS', 'ニュース'),
      el('div', { class: 'news', 'data-reveal': '' }, [
        tabs,
        list,
        el('a', { class: 'button-more', href: '#news' }, ['一覧を見る']),
      ]),
    ]),
  ])
}
