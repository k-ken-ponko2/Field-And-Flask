import { el, formatDate } from '../lib/dom'
import { movies } from '../data/media'
import type { MovieItem } from '../types'
import type { Modal } from '../lib/modal'
import { sectionHead } from './sectionHead'

function player(movie: MovieItem): HTMLElement {
  const frame = movie.embedUrl
    ? el('iframe', {
        class: 'movie-player__frame',
        src: movie.embedUrl,
        title: movie.title,
        allow: 'accelerometer; autoplay; encrypted-media; picture-in-picture',
        allowfullscreen: '',
        loading: 'lazy',
      })
    : el('div', { class: 'movie-player__placeholder' }, [
        el('p', {}, ['▶']),
        el('p', {}, ['ここに埋め込み動画が入ります']),
        el('p', { class: 'movie-player__hint' }, [
          'src/data/media.ts の embedUrl を設定してください。',
        ]),
      ])

  return el('div', { class: 'movie-player' }, [
    frame,
    el('div', { class: 'movie-player__meta' }, [
      el('h3', {}, [movie.title]),
      el('p', {}, [`${movie.subtitle} / ${movie.duration}`]),
    ]),
  ])
}

export function renderMovie(modal: Modal): HTMLElement {
  const cards = movies.map((movie, i) => {
    const card = el(
      'button',
      { class: 'movie-card', type: 'button', style: `--i:${i}` },
      [
        el('span', { class: 'movie-card__thumb' }, [
          el('span', { class: 'movie-card__play', 'aria-hidden': 'true' }, ['▶']),
          el('span', { class: 'movie-card__duration' }, [movie.duration]),
        ]),
        el('span', { class: 'movie-card__title' }, [movie.title]),
        el('span', { class: 'movie-card__sub' }, [movie.subtitle]),
        el('time', { class: 'movie-card__date', datetime: movie.publishedAt }, [
          formatDate(movie.publishedAt),
        ]),
      ],
    )
    card.addEventListener('click', () => modal.open(player(movie), movie.title))
    return card
  })

  return el('section', { class: 'section section--movie', id: 'movie', 'data-nav-target': '' }, [
    el('div', { class: 'container' }, [
      sectionHead('MOVIE', 'ムービー'),
      el('div', { class: 'movie-grid', 'data-reveal': '' }, cards),
    ]),
  ])
}
