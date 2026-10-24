// Draws one end's map in the turnaround facilities block over the basemap of
// maps/base_map.js: the standstill cells shaded in four levels, the last stop,
// the next trip's first stop, the location where buses stand and the toilet
// places. Everything drawn comes from the JSON the server put in the
// container. The endMap Alpine component loads this module on demand, so
// Leaflet reaches the route page only, once a map scrolls into view.
import L from "leaflet"

import { drawMap, pin, text, tip } from "../maps/base_map.js"

// Room left around what the view fits, in pixels.
const VIEW_PADDING = [24, 24]
// Markers on one spot stack with the location on top and the toilets at the bottom.
const Z_INDEX_OFFSET = { toilet: 0, stop: 1000, location: 2000 }

// Draws the map of `container`, a [data-end-map] element, and returns the
// handle that removes it and releases what it holds.
export function draw(container) {
  const data = JSON.parse(container.querySelector("[data-end-map-data]").textContent)
  const labels = JSON.parse(container.dataset.labels)
  return drawMap(container, "end-map", { minZoom: data.minZoom }, (map) => {
    map.fitBounds(viewBounds(data), { padding: VIEW_PADDING })
    data.cells.forEach((cell) => cellSquare(cell, data.cellDegrees).addTo(map))
    if (data.cells.length > 0) legend(labels).addTo(map)
    pin(data.lastStop, "end-map-pin end-map-stop end-map-stop-last", Z_INDEX_OFFSET.stop, tip(data.lastStop.name, labels.lastStop)).addTo(map)
    if (data.nextFirstStop) {
      pin(data.nextFirstStop, "end-map-pin end-map-stop end-map-stop-next", Z_INDEX_OFFSET.stop, tip(data.nextFirstStop.name, labels.nextFirstStop)).addTo(map)
    }
    // At a pass-through end the location is the last stop, which has its own marker.
    if (data.location?.source === "standstill") {
      pin(data.location, "end-map-pin end-map-location", Z_INDEX_OFFSET.location, tip(labels.location, data.location.day)).addTo(map)
    }
    data.places.forEach((place) => {
      const numbers = fill(labels.toilet, { meters: place.meters.toFixed(1), count: place.toilets })
      pin(place, "end-map-pin end-map-toilet", Z_INDEX_OFFSET.toilet, tip(place.name, place.category, numbers)).addTo(map)
    })
  })
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

// Replaces each {name} in `template` with values[name], taken as it is.
function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (placeholder, name) => (name in values ? String(values[name]) : placeholder))
}
