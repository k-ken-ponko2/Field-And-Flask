import './styles/reset.css'
import './styles/tokens.css'
import './styles/layout.css'
import './styles/components.css'

import { must } from './lib/dom'
import { runLoader } from './lib/loader'
import { initNav } from './lib/nav'
import { initReveal } from './lib/reveal'
import { Modal } from './lib/modal'
import { site } from './data/site'

import { renderHeader } from './sections/header'
import { renderHero } from './sections/hero'
import { renderNews } from './sections/news'
import { renderAbout } from './sections/about'
import { renderCharacters } from './sections/characters'
import { renderMovie } from './sections/movie'
import { renderMusic } from './sections/music'
import { renderFooter, renderSns } from './sections/sns'

function mount(): void {
  document.title = `${site.title} | ${site.titleEn} 公式サイト`
  const meta = document.querySelector('meta[name="description"]')
  meta?.setAttribute('content', site.description)

  const modal = new Modal()
  const app = must<HTMLElement>('#app')

  app.append(renderHeader())
  const main = document.createElement('main')
  main.append(
    renderHero(),
    renderNews(),
    renderAbout(),
    renderCharacters(modal),
    renderMovie(modal),
    renderMusic(),
    renderSns(),
  )
  app.append(main, renderFooter())
}

mount()
const { setCurrent } = initNav()
initReveal(setCurrent)
void runLoader()
