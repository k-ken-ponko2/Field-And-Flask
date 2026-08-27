import { must, prefersReducedMotion } from './dom'

/**
 * The opening loading screen: counts to 100, then hands off to the hero
 * animation. Resolves once the curtain is out of the way.
 */
export function runLoader(): Promise<void> {
  const loader = must<HTMLElement>('#loader')
  const counter = must<HTMLElement>('#loader-count', loader)
  const bar = must<HTMLElement>('#loader-bar', loader)

  const finish = () => {
    loader.classList.add('is-done')
    document.documentElement.classList.remove('is-locked')
    document.body.classList.add('is-ready')
    setTimeout(() => loader.remove(), 1200)
  }

  if (prefersReducedMotion()) {
    counter.textContent = '100'
    bar.style.setProperty('--progress', '1')
    finish()
    return Promise.resolve()
  }

  document.documentElement.classList.add('is-locked')

  return new Promise((resolve) => {
    let progress = 0
    const tick = () => {
      // Ease out: fast at first, hesitates near the end like a real preloader.
      progress = Math.min(100, progress + Math.max(0.6, (100 - progress) * 0.06))
      counter.textContent = String(Math.floor(progress)).padStart(3, '0')
      bar.style.setProperty('--progress', String(progress / 100))
      if (progress < 99.5) {
        requestAnimationFrame(tick)
        return
      }
      counter.textContent = '100'
      bar.style.setProperty('--progress', '1')
      setTimeout(() => {
        finish()
        resolve()
      }, 320)
    }
    requestAnimationFrame(tick)
  })
}
