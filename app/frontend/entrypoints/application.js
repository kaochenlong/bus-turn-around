import "@hotwired/turbo-rails"

import "alpine-turbo-drive-adapter"
import Alpine from "alpinejs"

import "../stylesheets/application.css"

// The home page's hero animation. The page is complete without it: the
// static picture stays when motion is reduced, WebGL is missing or the
// animation, loaded on demand, fails.
Alpine.data("homeHero", () => ({
  animation: null,

  async init() {
    // Turbo caches the page as the server sent it: the canvas is temporary,
    // and the state goes back to pending.
    this.restoreBeforeCache = () => { this.$el.dataset.hero = "pending" }
    document.addEventListener("turbo:before-cache", this.restoreBeforeCache)

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches || !webgl2Available()) {
      this.$el.dataset.hero = "static"
      return
    }
    this.$el.dataset.hero = "loading"
    try {
      const { start } = await import("../hero/runtime.js")
      if (this.$el.isConnected) this.animation = start(this.$el)
    } catch (error) {
      this.$el.dataset.hero = "static"
      reportError(error)
    }
  },

  // The pause button's: pauses the animation, or plays it on from the frame
  // it stopped on.
  toggle() {
    this.animation?.toggle()
  },

  destroy() {
    document.removeEventListener("turbo:before-cache", this.restoreBeforeCache)
    this.animation?.dispose()
    this.animation = null
  },
}))

// three.js renders with WebGL 2 only. The probe's context is let go at once.
function webgl2Available() {
  const gl = document.createElement("canvas").getContext("webgl2")
  gl?.getExtension("WEBGL_lose_context")?.loseContext()
  return gl !== null
}

// The share of a map container that has to be in the viewport before its map
// is loaded.
const MAP_VISIBLE_SHARE = 0.25

// One end's map in the turnaround facilities block. The page is complete
// without it: every number of the end is in the text above, and the
// container's sentence stays until the map, loaded on demand once a quarter of
// the container is in view, is drawn, and stays when it cannot be.
Alpine.data("endMap", () => ({
  map: null,

  init() {
    // Turbo caches the page as the server sent it: the map is let go, and the
    // state goes back to pending.
    this.restoreBeforeCache = () => {
      this.release()
      this.$el.dataset.map = "pending"
    }
    document.addEventListener("turbo:before-cache", this.restoreBeforeCache)

    // Judged by the share of the container inside: isIntersecting would be
    // true for any sliver.
    this.observer = new IntersectionObserver((entries) => {
      if (entries.at(-1).intersectionRatio < MAP_VISIBLE_SHARE) return
      this.observer.disconnect()
      this.load()
    }, { threshold: MAP_VISIBLE_SHARE })
    this.observer.observe(this.$el)
  },

  async load() {
    this.$el.dataset.map = "loading"
    try {
      const { draw } = await import("../end_map/runtime.js")
      if (!this.$el.isConnected) return
      this.map = draw(this.$el)
      this.$el.dataset.map = "ready"
    } catch (error) {
      this.$el.dataset.map = "static"
      reportError(error)
    }
  },

  release() {
    this.map?.dispose()
    this.map = null
  },

  destroy() {
    document.removeEventListener("turbo:before-cache", this.restoreBeforeCache)
    this.observer.disconnect()
    this.release()
  },
}))

// Turbo replaces the whole <body> when it renders a new page, and Alpine only
// cleans up a removed node it initialised itself, never <body>; without this
// the components of the old page are never destroyed. Morph renders are the
// adapter's job.
document.addEventListener("turbo:before-render", (event) => {
  if (event.detail.renderMethod !== "morph") Alpine.destroyTree(document.body)
})

window.Alpine = Alpine
Alpine.start()
