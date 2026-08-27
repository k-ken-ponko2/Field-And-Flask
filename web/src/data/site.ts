import type { SiteConfig } from '../types'

/**
 * All strings here are placeholder content for a fictional project.
 * Swap this file (and the other files in `src/data/`) to rebrand the site.
 */
export const site: SiteConfig = {
  title: 'ミッドナイト・ポート',
  titleEn: 'MIDNIGHT PORT',
  tagline: '眠らない港町の、案内人たち。',
  catchcopy: ['真夜中の港で', '君を待つ', '18の航路。'],
  description:
    '潮の匂いと灯りだけが残る深夜0時の港町。旅人を目的地へ送り届ける「案内人」たちの、ひと晩かぎりの物語。',
  copyright: '© 20XX YOUR COMPANY / MIDNIGHT PORT PROJECT',
  nav: [
    { id: 'news', label: 'ニュース', labelEn: 'NEWS' },
    { id: 'about', label: 'この物語について', labelEn: 'ABOUT' },
    { id: 'character', label: 'キャラクター', labelEn: 'CHARACTER' },
    { id: 'movie', label: 'ムービー', labelEn: 'MOVIE' },
    { id: 'music', label: 'ミュージック', labelEn: 'MUSIC' },
    { id: 'sns', label: '公式SNS', labelEn: 'SNS' },
  ],
}
