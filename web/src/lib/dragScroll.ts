/** Turns an overflow-x container into a pointer-draggable carousel. */
export function initDragScroll(container: HTMLElement): () => void {
  let pointerId: number | null = null
  let startX = 0
  let startScroll = 0
  let moved = false

  const onPointerDown = (event: PointerEvent) => {
    if (event.pointerType === 'touch') return // native momentum is better
    pointerId = event.pointerId
    startX = event.clientX
    startScroll = container.scrollLeft
    moved = false
    container.setPointerCapture(pointerId)
    container.classList.add('is-dragging')
  }

  const onPointerMove = (event: PointerEvent) => {
    if (pointerId !== event.pointerId) return
    const delta = event.clientX - startX
    if (Math.abs(delta) > 4) moved = true
    container.scrollLeft = startScroll - delta
  }

  const endDrag = (event: PointerEvent) => {
    if (pointerId !== event.pointerId) return
    container.releasePointerCapture(pointerId)
    pointerId = null
    container.classList.remove('is-dragging')
  }

  // Suppress the click that follows a drag, so cards don't activate.
  const onClickCapture = (event: MouseEvent) => {
    if (!moved) return
    event.preventDefault()
    event.stopPropagation()
    moved = false
  }

  container.addEventListener('pointerdown', onPointerDown)
  container.addEventListener('pointermove', onPointerMove)
  container.addEventListener('pointerup', endDrag)
  container.addEventListener('pointercancel', endDrag)
  container.addEventListener('click', onClickCapture, true)

  return () => {
    container.removeEventListener('pointerdown', onPointerDown)
    container.removeEventListener('pointermove', onPointerMove)
    container.removeEventListener('pointerup', endDrag)
    container.removeEventListener('pointercancel', endDrag)
    container.removeEventListener('click', onClickCapture, true)
  }
}
