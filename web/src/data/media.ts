import type { MovieItem, MusicItem, SnsLink } from '../types'

export const movies: readonly MovieItem[] = [
  {
    id: 'mv-03',
    title: 'ティザームービー 第2弾',
    subtitle: '「霧笛」',
    duration: '1:42',
    publishedAt: '2026-06-11',
    embedUrl: '',
  },
  {
    id: 'mv-02',
    title: 'キャラクターPV',
    subtitle: '岸壁班',
    duration: '2:05',
    publishedAt: '2026-05-02',
    embedUrl: '',
  },
  {
    id: 'mv-01',
    title: 'ティザームービー 第1弾',
    subtitle: '「出航」',
    duration: '1:08',
    publishedAt: '2026-03-18',
    embedUrl: '',
  },
]

export const musics: readonly MusicItem[] = [
  {
    id: 'ms-02',
    title: 'HARBOR LIGHTS',
    artist: '灯火班',
    releaseDate: '2026-09-16',
    tracks: ['夜明け前の合図', '待合室のワルツ', '灯台まで何歩', 'HARBOR LIGHTS (inst.)'],
    palette: ['#5a2a00', '#ffb547'],
  },
  {
    id: 'ms-01',
    title: 'MIDNIGHT PORT',
    artist: 'MIDNIGHT PORT ALL CAST',
    releaseDate: '2026-04-22',
    tracks: ['MIDNIGHT PORT', '潮位', '案内人のうた', 'MIDNIGHT PORT (inst.)'],
    palette: ['#0d2b4a', '#4dd6ff'],
  },
]

export const snsLinks: readonly SnsLink[] = [
  { id: 'x', label: 'X (Twitter)', handle: '@example_project', href: '#sns' },
  { id: 'youtube', label: 'YouTube', handle: 'MIDNIGHT PORT Channel', href: '#sns' },
  { id: 'instagram', label: 'Instagram', handle: '@example_project', href: '#sns' },
  { id: 'tiktok', label: 'TikTok', handle: '@example_project', href: '#sns' },
]
