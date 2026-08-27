import { el, must } from './dom'

const FOCUSABLE =
  'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])'

/** A single reusable dialog: focus-trapped, ESC/backdrop closable. */
export class Modal {
  private readonly root: HTMLElement
  private readonly body: HTMLElement
  private lastFocused: HTMLElement | null = null

  constructor(mountTo: HTMLElement = document.body) {
    this.body = el('div', { class: 'modal__body' })
    const close = el(
      'button',
      { class: 'modal__close', type: 'button', 'aria-label': '閉じる' },
      ['×'],
    )
    const panel = el(
      'div',
      { class: 'modal__panel', role: 'dialog', 'aria-modal': 'true', tabindex: '-1' },
      [close, this.body],
    )
    this.root = el('div', { class: 'modal', hidden: '' }, [
      el('div', { class: 'modal__backdrop', 'data-close': '' }),
      panel,
    ])

    close.addEventListener('click', () => this.close())
    must('[data-close]', this.root).addEventListener('click', () => this.close())
    this.root.addEventListener('keydown', (event) => this.onKeydown(event))
    mountTo.append(this.root)
  }

  open(content: Node, label: string): void {
    this.lastFocused = document.activeElement as HTMLElement | null
    this.body.replaceChildren(content)
    must('.modal__panel', this.root).setAttribute('aria-label', label)
    this.root.hidden = false
    document.documentElement.classList.add('is-locked')
    // Next frame, so the opening transition actually runs.
    requestAnimationFrame(() => {
      this.root.classList.add('is-open')
      must<HTMLElement>('.modal__panel', this.root).focus()
    })
  }

  close(): void {
    if (this.root.hidden) return
    this.root.classList.remove('is-open')
    document.documentElement.classList.remove('is-locked')
    const finish = () => {
      this.root.hidden = true
      this.body.replaceChildren()
      this.lastFocused?.focus()
    }
    this.root.addEventListener('transitionend', finish, { once: true })
    // Fallback if transitions are disabled.
    setTimeout(finish, 400)
  }

  private onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      this.close()
      return
    }
    if (event.key !== 'Tab') return
    const items = [...this.root.querySelectorAll<HTMLElement>(FOCUSABLE)].filter(
      (item) => item.offsetParent !== null,
    )
    if (items.length === 0) return
    const first = items[0]
    const last = items[items.length - 1]
    if (!first || !last) return
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }
}
