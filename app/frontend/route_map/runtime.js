// Draws the route map of the stop sequence block over the basemap of
// maps/base_map.js: one line per direction of the route shape that
// 臺北市公共運輸處 registers, and each direction's first and last stop. No
// other stop, vehicle or number is drawn. Everything drawn comes from the JSON
// the server put in the container. The routeMap Alpine component loads this
// module on demand, once the map scrolls into view.
import L from "leaflet"

import { drawMap, pin, text, tip } from "../maps/base_map.js"

// Room left around what the view fits, in pixels.
const VIEW_PADDING = [24, 24]
// Where one direction ends and the other starts at the same spot, the ring of
// the first stop lies over the dot of the last stop, so both stay visible.
const Z_INDEX_OFFSET = { lastStop: 0, firstStop: 1000 }

// Draws the map of `container`, a [data-route-map] element, and returns the
// handle that removes it and releases what it holds.
export function draw(container) {
  const data = JSON.parse(container.querySelector("[data-route-map-data]").textContent)
  const labels = JSON.parse(container.dataset.labels)
  return drawMap(container, "route-map", {}, (map) => {
    map.fitBounds(L.latLngBounds(data.lines.flatMap((line) => line.points)), { padding: VIEW_PADDING })
    // The stylesheet draws each direction's line; a line answers no pointer.
    data.lines.forEach((line) => {
      L.polyline(line.points, { className: `route-map-line route-map-line-${line.goBack}`, interactive: false }).addTo(map)
    })
    legend(data.lines, labels).addTo(map)
    data.endStops.forEach((stops) => {
      pin(stops.first, "route-map-pin route-map-stop route-map-stop-first", Z_INDEX_OFFSET.firstStop,
          tip(stops.first.name, labels.firstStop[stops.goBack])).addTo(map)
      pin(stops.last, "route-map-pin route-map-stop route-map-stop-last", Z_INDEX_OFFSET.lastStop,
          tip(stops.last.name, labels.lastStop[stops.goBack])).addTo(map)
    })
  })
}

// Each drawn direction, as a short stroke in its line's style and its name.
function legend(lines, labels) {
  const control = L.control({ position: "topright" })
  control.onAdd = () => {
    const element = L.DomUtil.create("div", "route-map-legend")
    lines.forEach((line) => {
      const entry = L.DomUtil.create("span", "route-map-legend-entry", element)
      L.DomUtil.create("span", `route-map-legend-swatch route-map-legend-swatch-${line.goBack}`, entry)
      entry.append(text(labels.directions[line.goBack]))
    })
    return element
  }
  return control
}
