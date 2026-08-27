import { prefersReducedMotion } from './dom'

/**
 * Adds `is-visible` to `[data-reveal]` elements as they enter the viewport,
 * and keeps `[data-nav-target]` sections in sync with the header's current
 * section indicator.
 */
export function initReveal(onSectionChange: (id: string) => void): () => void {
  const reduced = prefersReducedMotion()
  const targets = document.querySelectorAll<HTMLElement>('[data-reveal]')

  if (reduced) {
    for (const target of targets) target.classList.add('is-visible')
  }

  const revealObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.classList.add('is-visible')
        revealObserver.unobserve(entry.target)
      }
    },
    { rootMargin: '0px 0px -12% 0px', threshold: 0.12 },
  )
  if (!reduced) {
    for (const target of targets) revealObserver.observe(target)
  }

  const sections = document.querySelectorAll<HTMLElement>('[data-nav-target]')
  const sectionObserver = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((e) => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0]
      const id = visible?.target.id
      if (id) onSectionChange(id)
    },
    { rootMargin: '-45% 0px -45% 0px', threshold: [0, 0.25, 0.5, 1] },
  )
  for (const section of sections) sectionObserver.observe(section)

  return () => {
    revealObserver.disconnect()
    sectionObserver.disconnect()
  }
}
