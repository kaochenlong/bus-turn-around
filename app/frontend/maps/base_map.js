// What the maps of the route page share: a Leaflet map over the raster
// basemap the container names, set up for a long page that a reader scrolls
// through, and the markers and tooltips the maps draw. Every drawing module
// builds its map here, so the maps follow one set of interaction rules, and
// Leaflet with its stylesheet comes in one chunk that they all share.
import L from "leaflet"
import "leaflet/dist/leaflet.css"

// Every marker's box, which is what a pointer or a finger has to hit; the
// stylesheet draws the marker itself smaller inside it.
const PIN_SIZE = 24
// How long a gesture note stays after the last gesture, in milliseconds.
const GESTURE_NOTE_MS = 1200

// Draws a map into the [data-map-canvas] of `container`: a new element of
// class `className` holds a Leaflet map with the given `options`, over the
// tiles that the container's data-tile-url, data-tile-attribution and
// data-max-zoom name, and `drawLayers(map)` draws the rest. When drawing
// fails, the map and its element are removed before the error goes on.
// Returns the handle that removes the map and releases what it holds.
export function drawMap(container, className, options, drawLayers) {
  const maxZoom = Number(container.dataset.maxZoom)
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const coarsePointer = window.matchMedia("(pointer: coarse)").matches
  const element = document.createElement("div")
  element.className = className
  // Turbo caches the page as the server sent it: the map is temporary.
  element.dataset.turboTemporary = ""
  container.querySelector("[data-map-canvas]").append(element)
  const map = L.map(element, {
    ...options,
    maxZoom,
    // The container is hidden from assistive technology, so nothing in it may take focus.
    keyboard: false,
    // The map sits in a long page: the wheel zooms only with a key held (see
    // cooperativeGestures), and one finger on a touch screen scrolls the page
    // while two fingers move and zoom the map.
    scrollWheelZoom: true,
    // One notch of the wheel is half a zoom level: Leaflet's sigmoid gives
    // less than 0.5 for a notch on Mac and on Windows, rounded up to the
    // snap; with the default of 60 px a Windows notch would reach 0.57 and
    // round up to a whole level. The zoom buttons keep a whole level.
    zoomSnap: 0.5,
    wheelPxPerZoomLevel: 240,
    dragging: !coarsePointer,
    zoomAnimation: !reducedMotion,
    fadeAnimation: !reducedMotion,
    markerZoomAnimation: !reducedMotion,
  })
  try {
    map.attributionControl.setPrefix(false)
    map.zoomControl.getContainer().querySelectorAll("a").forEach((link) => { link.tabIndex = -1 })
    L.tileLayer(container.dataset.tileUrl, { attribution: escapeHtml(container.dataset.tileAttribution), maxZoom }).addTo(map)
    const labels = JSON.parse(container.dataset.baseMapLabels)
    const onWholeScreen = () => document.fullscreenElement === container
    cooperativeGestures(map, element, labels, onWholeScreen)
    fullscreenButton(map, container, labels, onWholeScreen, coarsePointer)
    drawLayers(map)
  } catch (error) {
    map.remove()
    element.remove()
    throw error
  }
  if (reducedMotion) container.dataset.animations = "off"

  return {
    dispose() {
      map.remove()
      element.remove()
      delete container.dataset.animations
    },
  }
}

// The gestures of Google Maps, for a map in a long page: the wheel and one
// finger scroll the page. The wheel zooms the map only with the zoom key held,
// ⌘ on a Mac and Ctrl elsewhere, and two fingers move and zoom it through
// Leaflet's touchZoom. A gesture meant for the page shows a note over the map
// saying what to do instead; `labels` gives its words, {key} left to fill.
// On the whole screen there is no page to scroll, and the map takes them all.
function cooperativeGestures(map, element, labels, onWholeScreen) {
  const note = document.createElement("div")
  note.className = "map-gesture-note"
  element.append(note)
  // navigator.platform is in every browser; navigator.userAgentData only in Chromium.
  const mac = /mac|iphone|ipad/i.test(navigator.platform)
  const key = mac ? "⌘" : "Ctrl"
  // A trackpad pinch sends a wheel turn with Ctrl held on every system, so
  // Ctrl zooms on a Mac too; without it the pinch would zoom the whole page.
  const zoomKeyHeld = (event) => event.ctrlKey || (mac && event.metaKey)
  let timer = null
  const hide = () => { delete note.dataset.shown }
  const show = (kind, text) => {
    note.textContent = text
    note.dataset.shown = kind
    clearTimeout(timer)
    timer = setTimeout(hide, GESTURE_NOTE_MS)
  }

  // In the capture phase this runs before Leaflet's own wheel listener on the
  // same element. A turn without the key never reaches Leaflet, and nothing
  // prevents it, so the page scrolls; one with the key is Leaflet's to zoom,
  // and the browser must not zoom the page as well.
  element.addEventListener("wheel", (event) => {
    if (onWholeScreen() || zoomKeyHeld(event)) {
      event.preventDefault()
      hide()
      return
    }
    event.stopPropagation()
    show("wheel", labels.wheelZoom.replace("{key}", key))
  }, { capture: true, passive: false })

  // One finger moves the map only where Leaflet's dragging is on: a mouse, or
  // any pointer on the whole screen.
  element.addEventListener("touchmove", (event) => {
    if (event.touches.length > 1 || onWholeScreen()) hide()
    else if (!map.dragging.enabled()) show("touch", labels.twoFingers)
  }, { passive: true })

  map.on("unload", () => clearTimeout(timer))
}

// Where the browser can show an element on the whole screen, a button below
// the zoom buttons shows the map container there and back; Safari on an
// iPhone cannot, and gets no button. On the whole screen dragging is on for
// every pointer; back in the page it is as drawMap set it. Leaflet measures
// the map again after each switch.
function fullscreenButton(map, container, labels, onWholeScreen, coarsePointer) {
  if (!document.fullscreenEnabled) return

  let button = null
  const describe = () => {
    const text = onWholeScreen() ? labels.exitFullscreen : labels.fullscreen
    button.title = text
    button.setAttribute("aria-label", text)
  }
  const control = L.control({ position: "topleft" })
  control.onAdd = () => {
    const bar = L.DomUtil.create("div", "leaflet-bar map-fullscreen")
    button = L.DomUtil.create("a", "", bar)
    button.href = "#"
    button.setAttribute("role", "button")
    // No focus, like the zoom buttons: the container is hidden from assistive technology.
    button.tabIndex = -1
    describe()
    L.DomEvent.disableClickPropagation(bar)
    L.DomEvent.on(button, "click", (event) => {
      L.DomEvent.preventDefault(event)
      const request = onWholeScreen() ? document.exitFullscreen() : container.requestFullscreen()
      request.catch(reportError)
    })
    return bar
  }
  control.addTo(map)

  const switched = () => {
    if (onWholeScreen()) {
      container.dataset.fullscreen = ""
      map.dragging.enable()
    } else {
      delete container.dataset.fullscreen
      if (coarsePointer) map.dragging.disable()
    }
    describe()
    map.invalidateSize()
  }
  document.addEventListener("fullscreenchange", switched)
  map.on("unload", () => {
    document.removeEventListener("fullscreenchange", switched)
    delete container.dataset.fullscreen
    if (onWholeScreen()) document.exitFullscreen().catch(reportError)
  })
}

// A marker that the stylesheet draws by `className`, opening `content` on
// hover or tap. A marker takes no focus, for the reason given in drawMap().
export function pin(point, className, zIndexOffset, content) {
  return L.marker([point.lat, point.lon], {
    icon: L.divIcon({ className, iconSize: [PIN_SIZE, PIN_SIZE] }),
    keyboard: false,
    zIndexOffset,
  }).bindTooltip(content, { direction: "top", offset: [0, -PIN_SIZE / 2] })
}

// Tooltip content: a bold first line and the lines after it that have a
// value, all set as plain text, since names come from outside data.
export function tip(...lines) {
  const content = document.createElement("div")
  lines.filter((line) => line !== null && line !== undefined && line !== "").forEach((line, index) => {
    const row = document.createElement(index === 0 ? "strong" : "div")
    row.textContent = line
    content.append(row)
  })
  return content
}

export function text(value) {
  const span = document.createElement("span")
  span.textContent = value
  return span
}

// Leaflet writes attributions as HTML; the configured attribution is plain text.
function escapeHtml(value) {
  const span = document.createElement("span")
  span.textContent = value
  return span.innerHTML
}
