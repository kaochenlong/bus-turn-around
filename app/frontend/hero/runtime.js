// Plays the hero animation once over the static picture it ends on. The
// homeHero Alpine component loads this module on demand, so three.js reaches
// the home page only.
import { DURATION, buildScene, createRenderer, pose, tallCamera, wideCamera } from "./scene.js"

// The picture's own breakpoint: narrower screens get the tall framing.
const NARROW = "(max-width: 639px)"
const MAX_PIXEL_RATIO = 2

// Starts the animation in `section`, the hero block, and returns the handle
// that stops it and releases what it holds.
export function start(section) {
  const stage = section.querySelector("[data-hero-stage]")
  const canvas = document.createElement("canvas")
  canvas.dataset.turboTemporary = ""
  canvas.setAttribute("aria-hidden", "true")
  const renderer = createRenderer(canvas)
  stage.append(canvas)

  const { scene, parts } = buildScene({ shadowMapSize: 2048 })
  const narrow = window.matchMedia(NARROW)
  const cameras = { tall: tallCamera(), wide: wideCamera() }
  let shot = narrow.matches ? "tall" : "wide"
  let frame = null
  let startedAt = null

  function render() {
    const { width, height } = stage.getBoundingClientRect()
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO))
    renderer.setSize(width, height, false)
    renderer.render(scene, cameras[shot])
  }

  function tick(now) {
    startedAt ??= now
    const t = Math.min((now - startedAt) / 1000 / DURATION, 1)
    pose(parts, t)
    render()
    if (t < 1) {
      frame = requestAnimationFrame(tick)
    } else {
      frame = null
      section.dataset.hero = "done"
    }
  }

  // Crossing 640 px switches the framing, as the picture does.
  function switchFraming() {
    shot = narrow.matches ? "tall" : "wide"
    section.dataset.heroShot = shot
  }

  // While it plays, every frame renders at the stage's size; after the end, a
  // new size (a new framing included) renders the last frame once more.
  const resized = new ResizeObserver(() => {
    if (frame === null) render()
  })

  section.dataset.heroShot = shot
  section.dataset.hero = "playing"
  narrow.addEventListener("change", switchFraming)
  frame = requestAnimationFrame(tick)
  resized.observe(stage)

  return {
    dispose() {
      if (frame !== null) cancelAnimationFrame(frame)
      frame = null
      narrow.removeEventListener("change", switchFraming)
      resized.disconnect()
      scene.traverse((object) => object.geometry?.dispose())
      renderer.dispose()
      renderer.forceContextLoss()
      canvas.remove()
    },
  }
}
