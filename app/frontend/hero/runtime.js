// Plays the hero animation over the static picture, round and round, while at
// least half of the illustration is in the viewport and the visitor has not
// paused it; otherwise it keeps the frame it stopped on and draws nothing
// until it plays again, carrying on from that moment. The homeHero Alpine
// component loads this module on demand, so three.js reaches the home page
// only.
import { aimNarrowCamera, buildScene, createRenderer, narrowCamera, pose, wideCamera } from "./scene.js"

// The picture's own breakpoint: narrower screens get the narrow framing.
const NARROW = "(max-width: 639px)"
const MAX_PIXEL_RATIO = 2
// The share of the illustration that has to be in the viewport for it to play.
const VISIBLE_SHARE = 0.5
// The most the animation moves on from one frame to the next, so that coming
// back to a tab the browser stopped drawing carries on where it was.
const MAX_STEP_SECONDS = 0.1

// Starts the animation in `section`, the hero block, and returns the handle
// that pauses and resumes it, and the one that stops it and releases what it
// holds.
export function start(section) {
  const stage = section.querySelector("[data-hero-stage]")
  const canvas = document.createElement("canvas")
  canvas.dataset.turboTemporary = ""
  canvas.setAttribute("aria-hidden", "true")
  const renderer = createRenderer(canvas)
  stage.append(canvas)

  const { scene, parts } = buildScene({ shadowMapSize: 2048 })
  const narrow = window.matchMedia(NARROW)
  const cameras = { narrow: narrowCamera(), wide: wideCamera() }
  let shot = narrow.matches ? "narrow" : "wide"
  let frame = null
  let seconds = 0
  let lastFrameAt = null
  let paused = false
  let inView = true

  function render() {
    const { width, height } = stage.getBoundingClientRect()
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO))
    renderer.setSize(width, height, false)
    if (shot === "narrow") aimNarrowCamera(cameras.narrow, seconds)
    renderer.render(scene, cameras[shot])
  }

  function tick(now) {
    frame = null
    if (lastFrameAt !== null) seconds += Math.min((now - lastFrameAt) / 1000, MAX_STEP_SECONDS)
    lastFrameAt = now
    pose(parts, seconds)
    render()
    play()
  }

  // Asks for the next frame unless the animation is paused or out of view.
  function play() {
    if (frame === null && !paused && inView) frame = requestAnimationFrame(tick)
  }

  // Stops asking for frames; the clock rests until play() starts it again.
  function rest() {
    if (frame !== null) cancelAnimationFrame(frame)
    frame = null
    lastFrameAt = null
  }

  function toggle() {
    paused = !paused
    section.dataset.hero = paused ? "paused" : "playing"
    if (paused) rest()
    else play()
  }

  // Crossing 640 px switches the framing, as the picture does.
  function switchFraming() {
    shot = narrow.matches ? "narrow" : "wide"
    section.dataset.heroShot = shot
  }

  // While it plays, every frame renders at the stage's size; while it rests, a
  // new size (a new framing included) renders the frame it rests on once more.
  const resized = new ResizeObserver(() => {
    if (frame === null) render()
  })

  // Whether enough of the illustration is in the viewport, judged by the
  // share of it inside: isIntersecting would be true for any sliver.
  const watched = new IntersectionObserver((entries) => {
    inView = entries.at(-1).intersectionRatio >= VISIBLE_SHARE
    if (inView) play()
    else rest()
  }, { threshold: VISIBLE_SHARE })

  section.dataset.heroShot = shot
  section.dataset.hero = "playing"
  narrow.addEventListener("change", switchFraming)
  // The first frame right away, so that the canvas is never blank, even when
  // the illustration starts out of view.
  pose(parts, seconds)
  render()
  play()
  resized.observe(stage)
  watched.observe(stage)

  return {
    toggle,
    dispose() {
      rest()
      narrow.removeEventListener("change", switchFraming)
      resized.disconnect()
      watched.disconnect()
      scene.traverse((object) => object.geometry?.dispose())
      renderer.dispose()
      renderer.forceContextLoss()
      canvas.remove()
    },
  }
}
