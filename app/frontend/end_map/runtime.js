// Draws one end's map in the turnaround facilities block over a raster
// basemap: the standstill cells shaded in four levels, the last stop, the next
// trip's first stop, the location where buses stand and the toilet places.
// Everything drawn comes from the JSON the server put in the container. The
// endMap Alpine component loads this module on demand, so Leaflet reaches the
// route page only, once a map scrolls into view.
import L from "leaflet"
import "leaflet/dist/leaflet.css"

// Room left around what the view fits, in pixels.
const VIEW_PADDING = [24, 24]
// Every marker's box, which is what a pointer or a finger has to hit; the
// stylesheet draws the marker itself smaller inside it.
const PIN_SIZE = 24
// Markers on one spot stack with the location on top and the toilets at the bottom.
const Z_INDEX_OFFSET = { toilet: 0, stop: 1000, location: 2000 }

// Draws the map of `container`, a [data-end-map] element, and returns the
// handle that removes it and releases what it holds.
export function draw(container) {
  const data = JSON.parse(container.querySelector("[data-end-map-data]").textContent)
  const labels = JSON.parse(container.dataset.labels)
  const maxZoom = Number(container.dataset.maxZoom)
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const element = document.createElement("div")
  element.className = "end-map"
  // Turbo caches the page as the server sent it: the map is temporary.
  element.dataset.turboTemporary = ""
  container.querySelector("[data-map-canvas]").append(element)
  const map = L.map(element, {
    minZoom: data.minZoom,
    maxZoom,
    // The container is hidden from assistive technology, so nothing in it may take focus.
    keyboard: false,
    // The map sits in a long page: the wheel scrolls the page, and so does one
    // finger on a touch screen, where two fingers zoom the map.
    scrollWheelZoom: false,
    dragging: !window.matchMedia("(pointer: coarse)").matches,
    zoomAnimation: !reducedMotion,
    fadeAnimation: !reducedMotion,
    markerZoomAnimation: !reducedMotion,
  })
  try {
    map.attributionControl.setPrefix(false)
    map.zoomControl.getContainer().querySelectorAll("a").forEach((link) => { link.tabIndex = -1 })
    L.tileLayer(container.dataset.tileUrl, { attribution: escapeHtml(container.dataset.tileAttribution), maxZoom }).addTo(map)
    map.fitBounds(viewBounds(data), { padding: VIEW_PADDING })
    data.cells.forEach((cell) => cellSquare(cell, data.cellDegrees).addTo(map))
    if (data.cells.length > 0) legend(labels).addTo(map)
    pin(data.lastStop, "end-map-stop end-map-stop-last", Z_INDEX_OFFSET.stop, tip(data.lastStop.name, labels.lastStop)).addTo(map)
    if (data.nextFirstStop) {
      pin(data.nextFirstStop, "end-map-stop end-map-stop-next", Z_INDEX_OFFSET.stop, tip(data.nextFirstStop.name, labels.nextFirstStop)).addTo(map)
    }
    // At a pass-through end the location is the last stop, which has its own marker.
    if (data.location?.source === "standstill") {
      pin(data.location, "end-map-location", Z_INDEX_OFFSET.location, tip(labels.location, data.location.day)).addTo(map)
    }
    data.places.forEach((place) => {
      const numbers = fill(labels.toilet, { meters: place.meters.toFixed(1), count: place.toilets })
      pin(place, "end-map-toilet", Z_INDEX_OFFSET.toilet, tip(place.name, place.category, numbers)).addTo(map)
    })
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

// What the view fits: the last stop, the next first stop, the location and
// every cell, each cell by both of its corners.
function viewBounds(data) {
  const bounds = L.latLngBounds([])
  for (const point of [data.lastStop, data.nextFirstStop, data.location]) {
    if (point) bounds.extend([point.lat, point.lon])
  }
  for (const cell of data.cells) bounds.extend(L.latLngBounds(cellCorners(cell, data.cellDegrees)))
  return bounds
}

// A cell's south-west corner and the corner `degrees` north-east of it.
function cellCorners(cell, degrees) {
  return [[cell.lat, cell.lon], [cell.lat + degrees, cell.lon + degrees]]
}

// The stylesheet shades a cell by its level; a cell answers no pointer.
function cellSquare(cell, degrees) {
  return L.rectangle(cellCorners(cell, degrees), { className: `end-map-cell end-map-cell-${cell.level}`, interactive: false })
}

// The four levels from few to many, without numbers.
function legend(labels) {
  const control = L.control({ position: "bottomleft" })
  control.onAdd = () => {
    const element = L.DomUtil.create("div", "end-map-legend")
    element.append(text(labels.few))
    for (const level of [1, 2, 3, 4]) L.DomUtil.create("span", `end-map-legend-swatch end-map-legend-${level}`, element)
    element.append(text(labels.many))
    return element
  }
  return control
}

// A marker that the stylesheet draws by `className`, opening `content` on
// hover or tap. A marker takes no focus, for the reason given in draw().
function pin(point, className, zIndexOffset, content) {
  return L.marker([point.lat, point.lon], {
    icon: L.divIcon({ className: `end-map-pin ${className}`, iconSize: [PIN_SIZE, PIN_SIZE] }),
    keyboard: false,
    zIndexOffset,
  }).bindTooltip(content, { direction: "top", offset: [0, -PIN_SIZE / 2] })
}

// Tooltip content: a bold first line and the lines after it that have a
// value, all set as plain text, since names come from outside data.
function tip(...lines) {
  const content = document.createElement("div")
  lines.filter((line) => line !== null && line !== undefined && line !== "").forEach((line, index) => {
    const row = document.createElement(index === 0 ? "strong" : "div")
    row.textContent = line
    content.append(row)
  })
  return content
}

function text(value) {
  const span = document.createElement("span")
  span.textContent = value
  return span
}

// Replaces each {name} in `template` with values[name], taken as it is.
function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (placeholder, name) => (name in values ? String(values[name]) : placeholder))
}

// Leaflet writes attributions as HTML; the configured attribution is plain text.
function escapeHtml(value) {
  const span = document.createElement("span")
  span.textContent = value
  return span.innerHTML
}
