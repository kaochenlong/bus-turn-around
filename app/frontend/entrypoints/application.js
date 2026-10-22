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

// Turbo replaces the whole <body> when it renders a new page, and Alpine only
// cleans up a removed node it initialised itself, never <body>; without this
// the components of the old page are never destroyed. Morph renders are the
// adapter's job.
document.addEventListener("turbo:before-render", (event) => {
  if (event.detail.renderMethod !== "morph") Alpine.destroyTree(document.body)
})

window.Alpine = Alpine
Alpine.start()
