import { el, formatDate } from '../lib/dom'
import { musics } from '../data/media'
import { portraitSvg, svgToDataUri } from '../lib/keyvisual'
import { initDragScroll } from '../lib/dragScroll'
import { sectionHead } from './sectionHead'

export function renderMusic(): HTMLElement {
  const track = el(
    'div',
    { class: 'music-track', tabindex: '0', 'aria-label': '楽曲リスト（横スクロール）' },
    musics.map((music, i) =>
      el('article', { class: 'music-card', style: `--i:${i};--accent:${music.palette[1]}` }, [
        el('div', {
          class: 'music-card__jacket',
          style: `background-image:${svgToDataUri(
            portraitSvg({ seed: music.id, palette: music.palette, width: 600, height: 600 }),
          )}`,
          'aria-hidden': 'true',
        }),
        el('div', { class: 'music-card__body' }, [
          el('time', { class: 'music-card__date', datetime: music.releaseDate }, [
            `${formatDate(music.releaseDate)} RELEASE`,
          ]),
          el('h3', { class: 'music-card__title' }, [music.title]),
          el('p', { class: 'music-card__artist' }, [music.artist]),
          el(
            'ol',
            { class: 'music-card__tracks' },
            music.tracks.map((t) => el('li', {}, [t])),
          ),
        ]),
      ]),
    ),
  )

  initDragScroll(track)

  return el('section', { class: 'section section--music', id: 'music', 'data-nav-target': '' }, [
    el('div', { class: 'container' }, [sectionHead('MUSIC', 'ミュージック')]),
    el('div', { class: 'music', 'data-reveal': '' }, [track]),
  ])
}
