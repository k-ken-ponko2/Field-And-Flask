import { el } from '../lib/dom'
import { site } from '../data/site'
import { sectionHead } from './sectionHead'

const STORY: readonly string[] = [
  '最終便が出たあとの港には、時刻表に載らない航路がある。',
  '行き先を失くした旅人を、朝までに送り届けること。それが「案内人」と呼ばれる彼らの仕事だ。',
  '桟橋、灯台、夜だけ開く売店。ひと晩の道のりで交わされる短い会話が、いつのまにか誰かの帰る場所になっていく。',
  '出航は毎晩、深夜0時。今夜あなたを担当するのは、さて、誰だろう。',
]

export function renderAbout(): HTMLElement {
  return el('section', { class: 'section section--about', id: 'about', 'data-nav-target': '' }, [
    el('div', { class: 'container' }, [
      sectionHead('ABOUT', 'この物語について'),
      el('div', { class: 'about' }, [
        el('div', { class: 'about__copy', 'data-reveal': '' }, [
          el('p', { class: 'about__catch' }, [site.tagline]),
          ...STORY.map((line) => el('p', { class: 'about__text' }, [line])),
        ]),
        el('aside', { class: 'about__meta', 'data-reveal': '' }, [
          el('dl', { class: 'about__dl' }, [
            el('dt', {}, ['タイトル']),
            el('dd', {}, [`${site.title}（${site.titleEn}）`]),
            el('dt', {}, ['ジャンル']),
            el('dd', {}, ['深夜の港町アドベンチャー']),
            el('dt', {}, ['配信予定']),
            el('dd', {}, ['20XX年 冬']),
            el('dt', {}, ['対応環境']),
            el('dd', {}, ['iOS / Android / PC']),
            el('dt', {}, ['価格']),
            el('dd', {}, ['基本プレイ無料（アイテム課金あり）']),
          ]),
        ]),
      ]),
    ]),
  ])
}
