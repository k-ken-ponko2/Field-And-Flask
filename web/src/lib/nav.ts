import { must, prefersReducedMotion } from './dom'

/** Hamburger + fullscreen overlay menu, with smooth in-page scrolling. */
export function initNav(): { setCurrent: (id: string) => void } {
  const header = must<HTMLElement>('#header')
  const toggle = must<HTMLButtonElement>('#nav-toggle')
  const overlay = must<HTMLElement>('#nav-overlay')
  const links = [...overlay.querySelectorAll<HTMLAnchorElement>('a[data-section]')]
  const headerLinks = [...header.querySelectorAll<HTMLAnchorElement>('a[data-section]')]

  const setOpen = (open: boolean) => {
    toggle.setAttribute('aria-expanded', String(open))
    overlay.classList.toggle('is-open', open)
    document.documentElement.classList.toggle('is-locked', open)
    overlay.setAttribute('aria-hidden', String(!open))
  }

  toggle.addEventListener('click', () => {
    setOpen(toggle.getAttribute('aria-expanded') !== 'true')
  })

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') setOpen(false)
  })

  for (const link of [...links, ...headerLinks]) {
    link.addEventListener('click', (event) => {
      const id = link.dataset['section']
      const target = id ? document.getElementById(id) : null
      if (!target) return
      event.preventDefault()
      setOpen(false)
      target.scrollIntoView({
        behavior: prefersReducedMotion() ? 'auto' : 'smooth',
        block: 'start',
      })
      history.replaceState(null, '', `#${id}`)
    })
  }

  let lastY = window.scrollY
  const onScroll = () => {
    const y = window.scrollY
    header.classList.toggle('is-scrolled', y > 80)
    // Hide on the way down, reveal on the way up.
    header.classList.toggle('is-hidden', y > lastY && y > 320)
    lastY = y
  }
  window.addEventListener('scroll', onScroll, { passive: true })
  onScroll()

  const setCurrent = (id: string) => {
    for (const link of [...links, ...headerLinks]) {
      link.classList.toggle('is-current', link.dataset['section'] === id)
    }
  }

  return { setCurrent }
}
