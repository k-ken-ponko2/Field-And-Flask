/** Content model for the site. All sections are rendered from these shapes. */

export type NewsCategory = 'news' | 'goods' | 'event' | 'media'

export interface NewsItem {
  readonly id: string
  /** ISO date, e.g. "2026-08-20". */
  readonly date: string
  readonly category: NewsCategory
  readonly title: string
  readonly href: string
  /** Marks the item with a "NEW" badge in the list. */
  readonly isNew?: boolean
}

export interface CharacterProfile {
  readonly label: string
  readonly value: string
}

export interface Character {
  readonly id: string
  readonly name: string
  readonly nameEn: string
  readonly unitId: string
  readonly catchphrase: string
  readonly description: string
  readonly cast: string
  readonly profile: readonly CharacterProfile[]
  /** Two hex colors used to generate this character's placeholder key art. */
  readonly palette: readonly [string, string]
}

export interface Unit {
  readonly id: string
  readonly name: string
  readonly nameEn: string
  readonly color: string
}

export interface MovieItem {
  readonly id: string
  readonly title: string
  readonly subtitle: string
  readonly duration: string
  readonly publishedAt: string
  /** Embed URL. Left empty in the template so nothing loads from a third party. */
  readonly embedUrl: string
}

export interface MusicItem {
  readonly id: string
  readonly title: string
  readonly artist: string
  readonly releaseDate: string
  readonly tracks: readonly string[]
  readonly palette: readonly [string, string]
}

export interface SnsLink {
  readonly id: string
  readonly label: string
  readonly handle: string
  readonly href: string
}

export interface NavItem {
  readonly id: string
  readonly label: string
  readonly labelEn: string
}

export interface SiteConfig {
  readonly title: string
  readonly titleEn: string
  readonly tagline: string
  readonly catchcopy: readonly string[]
  readonly description: string
  readonly copyright: string
  readonly nav: readonly NavItem[]
}
