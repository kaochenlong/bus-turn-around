// The timeline of the day dispatch, as in the day-dispatch-timeline spec,
// drawn into the markup and the templates DayTimelineComponent writes: one
// lane per vehicle on the time axis of day_timeline.js, every trip a button
// drawn as a bus seen from above on its current vehicle's lane, the stops at
// a stopping end, the recorded late returns, the vehicle changes, the typed
// departures, the mark and the line of now, and every lane's rest in the
// tightest four hours. Positions
// are percentages of the axis, so the lanes follow the page's width; which
// labels fit is worked out again when the axis changes width. A trip dragged
// with a mouse or a pen onto another vehicle's lane gives its departure to
// that vehicle, and along its own lane types its departure, by the rules of
// day.js the view is handed.
import { fitsLabel, laneAt, minuteAt, positionOf, timelineRange } from "./day_timeline.js"
import { fieldClock, fill, minutesText } from "./format.js"
import { OTHER_END } from "./layout.js"
import { SHORT_STOP_MINUTES } from "./rest_windows.js"

// The narrowest trip that shows its departure and the narrowest gap that
// shows its stop, in pixels. A trip is drawn as a bus, its rear window and
// windshield taking room on either side of its departure. A stop shorter
// than SHORT_STOP_MINUTES, which does not count as rest, shows below its gap
// however narrow the gap is.
const DEPARTURE_LABEL_PX = 36
const STOP_LABEL_PX = 13

// How far a pressed trip moves, in pixels, before it is dragged; a shorter
// move is a click, which selects it.
const DRAG_THRESHOLD_PX = 4

// From how many vehicles on the lanes are drawn lower, so that more of them
// fit in the frame.
const COMPACT_FROM = 12

// Where now shows across the frame when the timeline opens on a screen too
// narrow for the whole axis: this share of the axis's visible width from its
// left.
const NOW_AT = 0.4

// The view inside the timeline's section. labels: the day dispatch view's
// words; time(minutes) writes a time as the sheets do; vehicleName(number)
// and endName(end) name a vehicle and an end as the panel does;
// onSelect(tripId, { keyboard }) is told a trip was selected, by the
// keyboard or not, onNow that the mark of now was; previewDrop(tripId,
// vehicle) says what dropping a trip on a vehicle's lane would do,
// { exchanged: [trip identifiers of that vehicle] } or { refused }, and
// onDropOnLane(tripId, vehicle) is told it was dropped there;
// onDropAlongLane(tripId, departure) is told a trip was dropped along its
// own lane at another departure, in minutes of the kept day.
export function timelineView(section, { labels, time, vehicleName, endName, onSelect, onNow, previewDrop, onDropOnLane, onDropAlongLane }) {
  const words = JSON.parse(section.dataset.labels)
  const clone = (name) => section.querySelector(`template[data-timeline-${name}]`).content.firstElementChild.cloneNode(true)
  const slot = (name) => section.querySelector(`[data-slot=${name}]`)
  const ticks = slot("ticks")
  const nowMark = section.querySelector("[data-now]")
  const nowLine = section.querySelector("[data-now-line]")
  // What the timeline was drawn from: the day and its vehicles as they
  // stood, now, the selected trip, the time axis and its width in pixels,
  // and the trips' buttons in order of departure.
  let drawn = null
  // The trip pressed with a mouse or a pen: its button, its vehicle, the
  // pointer and where it grabbed the trip; once it moved, the ghost that
  // follows it, the lane it is over and, over its own lane, the departure it
  // points at.
  let drag = null
  // Whether the click that ends a drag is to be ignored: it is not a
  // selection.
  let dragged = false

  const view = {
    // The day as it stands drawn anew, now being minutes of the kept day
    // and selected the identifier of the selected trip, if any.
    draw(day, current, now, selected = null) {
      const range = timelineRange(current.vehicles)
      section.toggleAttribute("data-compact", current.vehicles.length >= COMPACT_FROM)
      // Every lane's axis is as wide as the axis of the ticks.
      drawn = { day, current, now, selected, range, axisPx: ticks.clientWidth }
      ticks.replaceChildren(nowMark, ...hours(range).map((hour) => placed(clone("hour-tick"), positionOf(hour * 60, range), String(hour).padStart(2, "0"))))
      slot("hour-lines").replaceChildren(...hours(range).map((hour) => placed(clone("hour-line"), positionOf(hour * 60, range))))
      const credits = new Map(current.credits.map((credit) => [credit.vehicle, credit]))
      const lanes = [...current.vehicles].sort((a, b) => a.number - b.number)
      slot("lanes").replaceChildren(...lanes.map((vehicle) => this.lane(vehicle, credits.get(vehicle.number))))
      this.order()
      this.moveNow(now)
      const stops = slot("legend-stops")
      stops.textContent = stopsAtText(day.stoppingEnds, words, endName) ?? ""
      stops.hidden = stops.textContent === ""
    },

    // Now at another minute, nothing else changing: the mark and the line of
    // now and the legend's time. The lanes and the trips stay as they are, so
    // a trip being dragged, selected or focused is left alone.
    moveNow(now) {
      drawn.now = now
      this.drawNow()
      slot("legend-now").textContent = fill(labels.nowLine, { time: time(now) })
    },

    // A vehicle's lane: its number and the vehicle changes it runs, its
    // trips with their marks, and its rest in the tightest four hours.
    lane(vehicle, credit) {
      const lane = clone("lane")
      lane.dataset.lane = vehicle.number
      lane.querySelector("[data-slot=vehicle]").textContent = vehicleName(vehicle.number)
      lane.querySelector("[data-slot=notes]").textContent = changesOn(vehicle).map(({ departure, from }) => fill(words.note, { time: time(departure), vehicle: vehicleName(from) })).join("\n")
      lane.querySelector("[data-slot=trips]").append(...this.marks(vehicle))
      lane.querySelector("[data-slot=credit]").textContent = minutesText(credit.now, labels.creditShorter, labels.creditMinutes)
      lane.querySelector("[data-slot=planned]").textContent = credit.now === credit.planned ? "" : minutesText(credit.planned, labels.creditPlannedShorter, labels.creditPlanned)
      return lane
    },

    // The stops at a stopping end below the trips, every trip as a button
    // with its outlines when it runs on another vehicle than planned or is
    // selected, and the late returns with their minutes.
    marks(vehicle) {
      const stops = []
      const trips = []
      vehicle.trips.forEach((trip, i) => {
        const next = vehicle.trips[i + 1]
        if (next && drawn.day.stoppingEnds.includes(trip.goBack) && next.stop >= 0) stops.push(this.stop(trip.arrival, next))
        trips.push(...this.trip(vehicle, trip))
      })
      return [...stops.filter(Boolean), ...trips]
    },

    // The stop between a trip's arrival and the next departure: its minutes
    // between the two when the gap holds them, below the gap when the stop
    // is short of rest; null for a gap too narrow for its minutes.
    stop(arrival, next) {
      const { range, axisPx } = drawn
      if (next.stop < SHORT_STOP_MINUTES) return placed(clone("short-stop"), positionOf((arrival + next.departure) / 2, range), fill(words.shortStop, { minutes: next.stop }))
      if (!fitsLabel(next.stop, range, axisPx, STOP_LABEL_PX)) return null
      return spanned(clone("stop"), arrival, next.departure, range, String(next.stop))
    },

    // A trip's button, a bus from its departure to its planned arrival, or to
    // its recorded arrival when that is earlier, its departure written on it
    // when it fits; a recorded arrival later than planned extends it,
    // labelled with the minutes late.
    trip(vehicle, trip) {
      const { range, axisPx, selected } = drawn
      const late = trip.recorded && trip.plannedArrival !== null && trip.arrival > trip.plannedArrival
      const end = late ? trip.plannedArrival : trip.arrival
      const button = spanned(clone("trip"), trip.departure, end, range)
      button.querySelector("[data-slot=label]").textContent = fitsLabel(end - trip.departure, range, axisPx, DEPARTURE_LABEL_PX) ? fieldClock(trip.departure) : ""
      const swapped = trip.plannedVehicle !== vehicle.number
      button.dataset.timelineTrip = trip.id
      button.dataset.goBack = trip.goBack
      button.dataset.departure = trip.departure
      button.toggleAttribute("data-typed", trip.typed)
      button.toggleAttribute("data-swapped", swapped)
      button.toggleAttribute("data-selected", trip.id === selected)
      button.setAttribute("aria-label", fill(words.trip, { vehicle: vehicleName(vehicle.number), time: time(trip.departure), stop: endName(trip.goBack), direction: words.directions[trip.goBack], arrival: time(trip.arrival) }))
      const marks = [button]
      if (swapped) marks.push(outlined(clone("swapped"), trip.departure, end, range, 3))
      if (trip.id === selected) marks.push(outlined(clone("selected"), trip.departure, end, range, 6))
      if (late) {
        // On lower lanes the minutes late sit on the extension's middle.
        const labelAt = section.hasAttribute("data-compact") ? (end + trip.arrival) / 2 : end
        marks.push(spanned(clone("late"), end, trip.arrival, range), placed(clone("late-label"), positionOf(labelAt, range), fill(words.late, { minutes: trip.arrival - end })))
      }
      return marks
    },

    // The trips in order of departure, the lower vehicle number first at
    // equal times. Tab reaches the earliest from the page and moves along
    // this order from there (see tab).
    order() {
      const laneOf = (button) => Number(button.closest("[data-lane]").dataset.lane)
      drawn.order = [...slot("lanes").querySelectorAll("[data-timeline-trip]")].sort((a, b) => Number(a.dataset.departure) - Number(b.dataset.departure) || laneOf(a) - laneOf(b))
      drawn.order.forEach((button, i) => { button.tabIndex = i === 0 ? 0 : -1 })
    },

    // Tab and Shift+Tab on a trip go to the next or the previous trip in
    // order of departure; past the last or the first, the page's own order
    // goes on.
    tab(event) {
      const index = drawn.order.indexOf(event.target)
      const next = index === -1 ? null : drawn.order[index + (event.shiftKey ? -1 : 1)]
      if (!next) return
      event.preventDefault()
      next.focus()
    },

    focusTrip(tripId) {
      slot("lanes").querySelector(`[data-timeline-trip="${tripId}"]`)?.focus()
    },

    // The frame scrolled sideways so now shows NOW_AT across the visible
    // axis, the vehicle numbers held at the left; nothing to do when the
    // whole axis fits or now is off the axis.
    scrollToNow() {
      const frame = section.querySelector("[data-timeline-frame]")
      if (nowLine.hidden || frame.scrollWidth <= frame.clientWidth) return
      const numbers = section.querySelector("[data-axis] > :first-child").getBoundingClientRect()
      const visible = frame.getBoundingClientRect().right - numbers.right
      frame.scrollLeft += nowLine.getBoundingClientRect().left - numbers.right - visible * NOW_AT
    },

    // The mark and the line of now, drawn only when now is on the time axis.
    drawNow() {
      const { now, range } = drawn
      const shown = range.start <= now && now <= range.end
      nowMark.hidden = !shown
      nowLine.hidden = !shown
      if (!shown) return
      nowMark.textContent = fill(labels.nowLine, { time: time(now) })
      placed(nowMark, positionOf(now, range))
      placed(nowLine, positionOf(now, range))
    },

    // A trip pressed with a mouse or a pen; touch only taps.
    press(event) {
      const button = event.target.closest("[data-timeline-trip]")
      if (!button || event.pointerType === "touch" || event.button !== 0) return
      const rect = button.getBoundingClientRect()
      drag = { button, lane: Number(button.closest("[data-lane]").dataset.lane), pointerId: event.pointerId, x: event.clientX, y: event.clientY, grab: { x: event.clientX - rect.left, y: event.clientY - rect.top }, departure: null }
      button.setPointerCapture(event.pointerId)
    },

    // The pressed trip follows the pointer once it moved far enough: its
    // place fades, a ghost of it rides on the pointer, and the lane under the
    // pointer is marked when it is another vehicle's.
    move(event) {
      if (!drag || event.pointerId !== drag.pointerId) return
      if (!drag.ghost && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < DRAG_THRESHOLD_PX) return
      if (!drag.ghost) this.lift()
      Object.assign(drag.ghost.style, { left: `${event.clientX - drag.grab.x}px`, top: `${event.clientY - drag.grab.y}px` })
      const lane = this.laneUnder(event.clientX, event.clientY)
      this.over(lane)
      drag.departure = lane?.number === drag.lane ? this.departureAt(event.clientX - drag.grab.x) : null
      const ghost = drag.ghost.getBoundingClientRect()
      if (drag.hint) Object.assign(drag.hint.style, { left: `${ghost.right + 8}px`, top: `${ghost.top - 4}px` })
      this.showDeparture(event.clientX, ghost.top)
    },

    // The whole minute the axis shows at a point of the page, held within
    // the time axis: where the ghost's left edge points is the departure the
    // trip would take.
    departureAt(x) {
      const axis = ticks.getBoundingClientRect()
      return minuteAt((x - axis.left) / axis.width, drawn.range)
    },

    // Over its own lane, the departure the dragged trip points at, written
    // above the pointer; gone anywhere else.
    showDeparture(x, top) {
      if (drag.departure === null) {
        drag.time?.remove()
        drag.time = null
        return
      }
      if (!drag.time) {
        drag.time = clone("drag-time")
        drag.time.style.position = "fixed"
        section.append(drag.time)
      }
      drag.time.textContent = fieldClock(drag.departure)
      Object.assign(drag.time.style, { left: `${x}px`, top: `${top - 26}px` })
    },

    // The pressed trip lifted for dragging: its place faded and a ghost of
    // it above the page, kept out of the keyboard's and the trips' way.
    lift() {
      this.clearRefusal()
      const rect = drag.button.getBoundingClientRect()
      const ghost = drag.button.cloneNode(true)
      for (const name of ["data-timeline-trip", "data-selected", "data-exchanged"]) ghost.removeAttribute(name)
      ghost.toggleAttribute("data-ghost", true)
      ghost.inert = true
      Object.assign(ghost.style, { position: "fixed", width: `${rect.width}px`, height: `${rect.height}px` })
      drag.button.toggleAttribute("data-dragging", true)
      section.append(ghost)
      drag.ghost = ghost
    },

    // The lane under a point of the page, inside the frame and below the
    // time axis held at its top; null over anything else.
    laneUnder(x, y) {
      const frame = section.querySelector("[data-timeline-frame]").getBoundingClientRect()
      const top = section.querySelector("[data-axis]").getBoundingClientRect().bottom
      if (x < frame.left || x > frame.right || y < top || y > frame.bottom) return null
      const lanes = [...slot("lanes").querySelectorAll("[data-lane]")].map((element) => {
        const rect = element.getBoundingClientRect()
        return { element, number: Number(element.dataset.lane), top: rect.top, bottom: rect.bottom }
      })
      return laneAt(lanes, y)
    },

    // Another vehicle's lane under the dragged trip marked as the target:
    // when the change applies, the trips it would exchange outlined and a
    // hint saying from which departure the two vehicles exchange their day.
    over(lane) {
      if (lane?.element === drag.over?.element) return
      this.unmark()
      drag.over = lane
      if (!lane || lane.number === drag.lane) return
      lane.element.toggleAttribute("data-drop-target", true)
      const preview = previewDrop(drag.button.dataset.timelineTrip, lane.number)
      if (preview.refused) return
      for (const id of preview.exchanged) {
        const trip = lane.element.querySelector(`[data-timeline-trip="${id}"]`)
        trip.toggleAttribute("data-exchanged", true)
        const ring = clone("exchange")
        Object.assign(ring.style, { left: `calc(${trip.style.left} - 3px)`, width: `calc(${trip.style.width} + 6px)` })
        trip.after(ring)
      }
      drag.hint = clone("drag-hint")
      drag.hint.textContent = fill(words.dragHint, { vehicle: vehicleName(lane.number), time: time(Number(drag.button.dataset.departure)) })
      drag.hint.style.position = "fixed"
      section.append(drag.hint)
    },

    // No lane marked as the target any more: its tint, the outlines of the
    // trips it would exchange and the hint gone.
    unmark() {
      for (const element of section.querySelectorAll("[data-drop-target], [data-exchanged]")) element.removeAttribute(element.matches("[data-lane]") ? "data-drop-target" : "data-exchanged")
      for (const element of section.querySelectorAll("[data-exchange], [data-drag-hint]")) element.remove()
      if (drag) drag.hint = null
    },

    // The trip let go: on another vehicle's lane its departure goes to that
    // vehicle, along its own lane it departs at the minute it points at;
    // anywhere else nothing changes. A press that never moved is a click,
    // left to select the trip.
    release(event) {
      if (!drag || event.pointerId !== drag.pointerId) return
      const { button, ghost, over, lane, departure } = drag
      this.cancel()
      if (!ghost) return
      dragged = true
      const tripId = button.dataset.timelineTrip
      if (over && over.number !== lane) onDropOnLane(tripId, over.number)
      else if (departure !== null && departure !== Number(button.dataset.departure)) onDropAlongLane(tripId, departure)
    },

    // The drag ended without a drop: the ghost and the marks gone, the trip
    // back in its place.
    cancel() {
      if (!drag) return
      this.unmark()
      drag.ghost?.remove()
      drag.time?.remove()
      drag.button.removeAttribute("data-dragging")
      drag = null
    },

    // Why dropping a trip on a vehicle's lane changed nothing, said under
    // that lane until the timeline is drawn again or another drag starts.
    refuse(vehicle, text) {
      this.clearRefusal()
      const message = clone("drop-message")
      message.textContent = text
      slot("lanes").querySelector(`[data-lane="${vehicle}"]`).after(message)
    },

    clearRefusal() {
      slot("lanes").querySelector("[data-drop-message]")?.remove()
    },
  }

  const lanes = slot("lanes")
  lanes.addEventListener("pointerdown", (event) => view.press(event))
  lanes.addEventListener("pointermove", (event) => view.move(event))
  lanes.addEventListener("pointerup", (event) => view.release(event))
  lanes.addEventListener("pointercancel", () => view.cancel())
  lanes.addEventListener("keydown", (event) => {
    if (event.key === "Tab") view.tab(event)
    if (event.key !== "Escape" || !drag?.ghost) return
    view.cancel()
    dragged = true
  })
  // Enter on a trip clicks it with no pointer, which a click's detail of 0 tells.
  lanes.addEventListener("click", (event) => {
    const trip = event.target.closest("[data-timeline-trip]")
    if (dragged) dragged = false
    else if (trip) onSelect(trip.dataset.timelineTrip, { keyboard: event.detail === 0 })
  })
  nowMark.addEventListener("click", () => onNow())
  // Which labels fit follows the axis's width: drawn again when it changes.
  new ResizeObserver(() => {
    if (drawn && ticks.clientWidth !== drawn.axisPx) view.draw(drawn.day, drawn.current, drawn.now, drawn.selected)
  }).observe(ticks)
  return view
}

// The vehicle changes a vehicle runs, in order: every departure from which
// it runs another vehicle's trips, with that vehicle.
export function changesOn(vehicle) {
  return vehicle.trips.flatMap((trip, i) => {
    const before = vehicle.trips[i - 1]
    if (trip.plannedVehicle === vehicle.number || before?.plannedVehicle === trip.plannedVehicle) return []
    return [{ departure: trip.departure, from: trip.plannedVehicle }]
  })
}

// What the stops between the trips are: the stops at the one end where
// vehicles stop, or at both ends; null when vehicles stop at neither end.
// stoppingEnds: the directions whose trips end at a stopping end.
export function stopsAtText(stoppingEnds, words, endName) {
  const ends = stoppingEnds.map((goBack) => OTHER_END[goBack])
  if (ends.length === 0) return null
  return fill(words.stopsAt, { stop: ends.length > 1 ? words.bothEnds : endName(ends[0]) })
}

// The whole hours of the time axis, its ends included.
function hours({ start, end }) {
  return Array.from({ length: (end - start) / 60 + 1 }, (_, i) => start / 60 + i)
}

const percent = (value) => `${value.toFixed(4)}%`

// An element placed at a point of the axis, with its text when given.
function placed(element, position, text) {
  element.style.left = percent(position)
  if (text !== undefined) element.textContent = text
  return element
}

// An element spanning the axis from one time to another, with its text when
// given.
function spanned(element, from, to, range, text) {
  const left = positionOf(from, range)
  element.style.width = percent(positionOf(to, range) - left)
  return placed(element, left, text)
}

// An outline around the stretch from one time to another, the given pixels
// outside it on either side.
function outlined(element, from, to, range, outside) {
  const left = positionOf(from, range)
  element.style.left = `calc(${percent(left)} - ${outside}px)`
  element.style.width = `calc(${percent(positionOf(to, range) - left)} + ${2 * outside}px)`
  return element
}
