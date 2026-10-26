import "@hotwired/turbo-rails"

import "alpine-turbo-drive-adapter"
import Alpine from "alpinejs"

import "../stylesheets/application.css"

import { installRestCommand } from "../rest_command.js"
import { timetable } from "../timetable/component.js"
import { dayDispatch } from "../timetable/day_page.js"

// The timetable page: the server embeds the measured data, the browser lays
// the timetable out and recomputes the dispatcher's edits.
Alpine.data("timetable", timetable)

// The day dispatch page: the day lives in this browser, which shows it and
// works out every change.
Alpine.data("dayDispatch", dayDispatch)

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

// A map container's Alpine component. `load` imports the module whose draw()
// draws the map; it runs once a quarter of the container is in view. The page
// is complete without the map: the container's sentence stays until the map
// is drawn, and stays when it cannot be. Each caller writes out its own
// import(), so that Vite gives each kind of map a chunk of its own.
function lazyMap(load) {
  return {
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
        this.loadMap()
      }, { threshold: MAP_VISIBLE_SHARE })
      this.observer.observe(this.$el)
    },

    async loadMap() {
      this.$el.dataset.map = "loading"
      try {
        const { draw } = await load()
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
  }
}

// One end's map in the turnaround facilities block; every number of the end
// is in the text above it.
Alpine.data("endMap", () => lazyMap(() => import("../end_map/runtime.js")))

// The route map of the stop sequence block; every stop is in the list below it.
Alpine.data("routeMap", () => lazyMap(() => import("../route_map/runtime.js")))

// The buffer estimate's rest and lateness sliders. The server writes every
// point of the cost curve into the block, with the strings the block shows and
// the marker's coordinates; moving a slider copies the point at rest plus
// lateness into the block and puts the two values in the address, without a
// request. It computes nothing. The block is complete without it: the form
// sends every value to the server.
Alpine.data("bufferTrade", () => ({
  curve: null,

  init() {
    const data = this.$root.querySelector("script[data-buffer-trade-curve]")
    this.curve = data ? JSON.parse(data.textContent) : null
    // Back from Turbo's cache the sliders carry the moved values: show their
    // point, so the figures and the address agree.
    this.show()
  },

  // A slider's input: the new values on the page, on the sliders themselves
  // for Turbo's cache, and in the address without a history entry.
  move() {
    this.show()
    for (const slider of this.$root.querySelectorAll("input[type=range]")) slider.setAttribute("value", slider.value)
    const url = new URL(window.location.href)
    url.searchParams.set("buffer", this.slider("buffer"))
    url.searchParams.set("late", this.slider("late"))
    window.history.replaceState(window.history.state, "", url)
  },

  slider(name) {
    return Number(this.$root.querySelector(`input[name="${name}"]`).value)
  },

  show() {
    const rest = this.slider("buffer")
    const late = this.slider("late")
    const hold = rest + late
    this.text("minutes", rest)
    this.text("late", late)
    this.text("hold", hold)
    const achievedLate = this.$root.querySelector("[data-achieved-late]")
    if (achievedLate) achievedLate.hidden = late === 0
    if (!this.curve) return

    const point = this.curve.points[hold]
    this.text("vehicle-hours-lower", point.vehicle_hours[0])
    this.text("vehicle-hours-upper", point.vehicle_hours[1])
    this.text("next-minute-lower", point.next_minute[0])
    this.text("next-minute-upper", point.next_minute[1])
    this.text("achieved", this.curve.points[rest].achieved)
    this.text("achieved-late", point.achieved)
    ;["lower", "upper"].forEach((bound, index) => {
      const peak = this.$root.querySelector(`[data-peak="${bound}"]`)
      peak.querySelector("[data-peak-hour]").textContent = point.peak[index][0]
      peak.querySelector("[data-vehicles]").textContent = point.peak[index][1]
    })
    this.$root.querySelectorAll("details[data-hourly] tr[data-hour]").forEach((row, index) => {
      row.querySelector('[data-hourly-bound="lower"]').textContent = point.hourly[index][0]
      row.querySelector('[data-hourly-bound="upper"]').textContent = point.hourly[index][1]
    })
    this.mark(point.marker)
  },

  // Every element of the block showing the named figure.
  text(name, value) {
    for (const node of this.$root.querySelectorAll(`[data-value="${name}"]`)) node.textContent = value
  },

  mark({ x, lower_y: lowerY, upper_y: upperY }) {
    const line = this.$root.querySelector("[data-marker-line]")
    line.setAttribute("x1", x)
    line.setAttribute("x2", x)
    line.setAttribute("y2", upperY)
    for (const [bound, y] of [["lower", lowerY], ["upper", upperY]]) {
      const dot = this.$root.querySelector(`[data-marker-dot="${bound}"]`)
      dot.setAttribute("cx", x)
      dot.setAttribute("cy", y)
    }
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

// The console's 休息() and its hint. A Turbo visit does not run this entry
// again, so the hint is written once a full load, not on every page.
installRestCommand()
