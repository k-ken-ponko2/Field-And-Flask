import { el } from '../lib/dom'
import { characters, units } from '../data/characters'
import type { Character } from '../types'
import { portraitSvg, svgToDataUri } from '../lib/keyvisual'
import type { Modal } from '../lib/modal'
import { sectionHead } from './sectionHead'

function unitOf(character: Character) {
  return units.find((u) => u.id === character.unitId)
}

function detail(character: Character): HTMLElement {
  const unit = unitOf(character)
  return el('article', { class: 'char-detail', style: `--accent:${character.palette[1]}` }, [
    el('div', {
      class: 'char-detail__visual',
      style: `background-image:${svgToDataUri(
        portraitSvg({ seed: character.id, palette: character.palette }),
      )}`,
      'aria-hidden': 'true',
    }),
    el('div', { class: 'char-detail__body' }, [
      el('p', { class: 'char-detail__unit' }, [unit ? `${unit.nameEn} / ${unit.name}` : '']),
      el('h3', { class: 'char-detail__name' }, [
        character.name,
        el('span', { class: 'char-detail__name-en' }, [character.nameEn]),
      ]),
      el('p', { class: 'char-detail__catch' }, [`「${character.catchphrase}」`]),
      el('p', { class: 'char-detail__desc' }, [character.description]),
      el(
        'dl',
        { class: 'char-detail__profile' },
        character.profile.flatMap((p) => [el('dt', {}, [p.label]), el('dd', {}, [p.value])]),
      ),
      el('p', { class: 'char-detail__cast' }, [character.cast]),
    ]),
  ])
}

export function renderCharacters(modal: Modal): HTMLElement {
  const grid = el('div', { class: 'char-grid' })

  const paint = (unitId: string) => {
    const list = unitId === 'all' ? characters : characters.filter((c) => c.unitId === unitId)
    grid.replaceChildren(
      ...list.map((character, i) => {
        const card = el(
          'button',
          {
            class: 'char-card',
            type: 'button',
            style: `--i:${i};--accent:${character.palette[1]}`,
            'aria-label': `${character.name} の詳細を開く`,
          },
          [
            el('span', {
              class: 'char-card__visual',
              style: `background-image:${svgToDataUri(
                portraitSvg({ seed: character.id, palette: character.palette }),
              )}`,
            }),
            el('span', { class: 'char-card__meta' }, [
              el('span', { class: 'char-card__unit' }, [unitOf(character)?.nameEn ?? '']),
              el('span', { class: 'char-card__name' }, [character.name]),
              el('span', { class: 'char-card__name-en' }, [character.nameEn]),
            ]),
            el('span', { class: 'char-card__catch' }, [character.catchphrase]),
          ],
        )
        card.addEventListener('click', () => modal.open(detail(character), character.name))
        return card
      }),
    )
  }

  const filters = el(
    'div',
    { class: 'char-filters', role: 'tablist', 'aria-label': 'ユニットで絞り込み' },
    [{ id: 'all', nameEn: 'ALL', name: 'すべて', color: 'currentColor' }, ...units].map(
      (unit, i) => {
        const button = el(
          'button',
          {
            class: 'char-filter',
            type: 'button',
            role: 'tab',
            'aria-selected': String(i === 0),
            style: `--accent:${unit.color}`,
          },
          [el('span', { class: 'char-filter__en' }, [unit.nameEn]), el('span', {}, [unit.name])],
        )
        button.addEventListener('click', () => {
          for (const other of filters.querySelectorAll('.char-filter')) {
            other.setAttribute('aria-selected', String(other === button))
          }
          paint(unit.id)
        })
        return button
      },
    ),
  )

  paint('all')

  return el(
    'section',
    { class: 'section section--character', id: 'character', 'data-nav-target': '' },
    [
      el('div', { class: 'container' }, [
        sectionHead('CHARACTER', 'キャラクター'),
        el('div', { 'data-reveal': '' }, [filters, grid]),
      ]),
    ],
  )
}
