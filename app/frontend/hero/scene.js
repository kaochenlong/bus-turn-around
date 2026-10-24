// The hero illustration of the home page: a three.js scene shared by the home
// page, which plays its animation on a loop, and by the export page in
// tools/hero, which saves the still as the WebP files the home page falls
// back to (app/assets/images/home-hero-wide.webp and home-hero-narrow.webp).
//
// One turnaround after another: a bus drives into the terminal and stops,
// the front door opens and the driver steps out to rest beside it, then gets
// back in; the bus pulls up to the stop on the right, where the waiting
// riders board, and drives off; new riders walk to the stop and the next bus
// comes in. On the left the dispatch office's window. Orthographic cameras
// at a fixed angle from above, one directional light and a hemisphere light,
// flat Lambert materials and a transparent background.
import * as THREE from "three"
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js"

// The route page's palette (Tailwind v4, approximate hex), and nothing else
// but SKIN and GREEN_600, two colours the route page has no use for: the
// people's skin and the plants. (The poster in the office is a picture with
// colours of its own.)
const SLATE_100 = 0xf1f5f9 // the ground, the bus body, the office walls and other light parts
const SLATE_300 = 0xcbd5e1 // the road, lamps, the roof unit and the board's cells
const SLATE_600 = 0x475569 // clothes
const SLATE_800 = 0x1e293b // windows, hair, eyes and dark parts
const TEAL_500 = 0x14b8a6 // clothes
const TEAL_700 = 0x0f766e // the band on the bus and the office door
const AMBER_400 = 0xfbbf24 // the one accent: the stop sign, a few cells of the board and the words on the bus's sign
const SKIN = 0xf1d6c2 // everyone's head and face, the same for all
const GREEN_600 = 0x16a34a // the crowns of the street trees and the shrubs, and nothing else

// The two framings' sizes in pixels: the wide one, and the narrow one for
// narrow screens. The static images are exported at these sizes
// (tools/hero/export.js) and the cameras take their aspect from them; over
// budget, the export drops to 1600×762 and 900×600, about the same aspects.
// Neither leaves a band of empty space above and below: the wide one is about
// as wide as the block it frames, about 2.1:1, and the narrow one, which
// frames the terminal or the stop, is 3:2.
export const WIDE = { width: 2048, height: 976 }
export const NARROW = { width: 1170, height: 780 }

// Everything beyond the left and right edges of the block is cut away, so the
// bus and the riders come and go through the cut rather than over the
// transparent background.
const BLOCK_EDGES = [new THREE.Plane(new THREE.Vector3(1, 0, 0), 15), new THREE.Plane(new THREE.Vector3(-1, 0, 0), 15)]

// Where the stop stands, on the pavement beside the road.
const STOP_AT = { x: 11.4, z: 1.3 }

// Returns the scene, its three groups, left to right (the dispatch office
// window, the terminal with the bus and its driver, and the stop), and the
// parts the animation moves, posed at the still. The export renders shadows
// from a 4096 map; the home page asks for a smaller one.
export function buildScene({ shadowMapSize = 4096 } = {}) {
  const scene = new THREE.Scene()
  addLights(scene, shadowMapSize)
  scene.add(ground())

  const dispatch = new THREE.Group()
  dispatch.add(dispatchOffice())
  dispatch.position.set(-11.4, 0, 3.3)

  const { group: busGroup, frontLeaf, rearLeaf, sign } = bus()
  clipToBlock(busGroup)
  const { figure: driver, arms: driverArms } = person(TEAL_500)
  const terminal = new THREE.Group()
  terminal.add(busGroup, driver)
  terminal.position.set(0, 0, -1.55)

  const waiting = riders()
  const stop = new THREE.Group()
  stop.add(stopSign(), ...waiting.map(({ figure }) => figure))
  stop.position.set(STOP_AT.x, 0, STOP_AT.z)

  scene.add(dispatch, terminal, stop, greenery())
  const parts = { bus: busGroup, frontLeaf, rearLeaf, sign, driver, driverArms, riders: waiting }
  pose(parts, STILL)
  return { scene, dispatch, terminal, stop, parts }
}

// The animation, in seconds: the bus drives in from beyond the left edge of
// the block and stops, the front door opens, the driver steps out of it,
// walks to the side of the bus and leans back against it, stretches once,
// then turns, walks back in and the door closes. The bus pulls up to the
// stop, where the riders board in turn (RIDERS), and drives out beyond the
// right edge, while new riders walk in to wait for the next bus. It loops
// every CYCLE seconds; STILL, the driver resting beside the bus, is the frame
// the site serves as images.
export const CYCLE = 21
export const STILL = 5.5
const TIMELINE = {
  drive: [0, 3.0],
  door: [3.0, 3.8],
  stepOut: [3.8, 4.6],
  walk: [4.6, 5.2],
  lean: [5.2, 5.4],
  raiseArms: [6.3, 7.0],
  lowerArms: [7.2, 7.9],
  straighten: [8.4, 8.6],
  turnAlong: [8.6, 8.8],
  walkBack: [8.8, 9.4],
  turnIn: [9.4, 9.6],
  stepIn: [9.6, 10.2],
  doorClose: [10.2, 11.0],
  pullUp: [11.0, 12.6],
  doorAtStop: [12.6, 13.4],
  doorCloseAtStop: [16.2, 17.0],
  depart: [17.0, 19.4],
}
const BUS_START_X = -22 // the whole bus beyond the left edge of the block
const BUS_END_X = 22 // the whole bus beyond the right edge of the block
const FRONT_LEAF_DEGREES = 62 // swung out
const REAR_LEAF_DEGREES = 90 // folded into the bus, then out of sight
const DOORWAY = { x: 4.9, z: 0.9 } // inside the bus, hidden by its body
const RESTING = { x: 4.15, z: 1.63, lean: -0.12 } // between the front wheel and the open door
const STRETCH_DEGREES = -175 // both arms straight up over the head

// Where riders board, in the stop's coordinates: off the kerb in front of the
// front door, then inside the bus, hidden by its body. At the stop, the bus
// stands with its doorway there, just past the sign, which from the camera's
// angle would hide a doorway right behind it.
const KERBSIDE = [0.5, -1.2]
const ABOARD = [0.5, -1.95]
const AT_STOP_X = STOP_AT.x + KERBSIDE[0] - DOORWAY.x

// Puts the moving parts where they are `seconds` into the animation, counted
// round the loop, and lights the bus's destination sign while the driver is
// out; pose(parts, STILL) is the still. Each move back undoes the one out, so
// the driver walks back the way they came: along the bus, then in through the
// door.
export function pose({ bus, frontLeaf, rearLeaf, sign, driver, driverArms, riders }, seconds) {
  const at = THREE.MathUtils.euclideanModulo(seconds, CYCLE)
  const phase = (span) => easeInOut(progress(at, span))
  bus.position.x =
    THREE.MathUtils.lerp(BUS_START_X, 0, easeOut(progress(at, TIMELINE.drive))) +
    AT_STOP_X * phase(TIMELINE.pullUp) +
    (BUS_END_X - AT_STOP_X) * easeIn(progress(at, TIMELINE.depart))

  const door = phase(TIMELINE.door) - phase(TIMELINE.doorClose) + phase(TIMELINE.doorAtStop) - phase(TIMELINE.doorCloseAtStop)
  frontLeaf.rotation.y = THREE.MathUtils.degToRad(FRONT_LEAF_DEGREES * door)
  rearLeaf.rotation.y = THREE.MathUtils.degToRad(REAR_LEAF_DEGREES * door)
  rearLeaf.visible = door < 1

  // Inside the bus the driver is hidden, so that the bus can drive off
  // without leaving them standing on the road.
  driver.visible = at >= TIMELINE.stepOut[0] && at < TIMELINE.stepIn[1]
  driver.position.set(
    THREE.MathUtils.lerp(DOORWAY.x, RESTING.x, phase(TIMELINE.walk) - phase(TIMELINE.walkBack)),
    0,
    THREE.MathUtils.lerp(DOORWAY.z, RESTING.z, phase(TIMELINE.stepOut) - phase(TIMELINE.stepIn)),
  )
  driver.rotation.x = RESTING.lean * (phase(TIMELINE.lean) - phase(TIMELINE.straighten))
  driver.rotation.y = (Math.PI / 2) * (phase(TIMELINE.turnAlong) + phase(TIMELINE.turnIn))
  const stretch = THREE.MathUtils.degToRad(STRETCH_DEGREES) * (phase(TIMELINE.raiseArms) - phase(TIMELINE.lowerArms))
  for (const shoulder of driverArms) shoulder.rotation.x = stretch

  poseSign(sign, at)
  for (const rider of riders) poseRider(rider, at)
}

// How far `seconds` is through the span [from, to], from 0 to 1.
function progress(seconds, [from, to]) {
  return THREE.MathUtils.clamp((seconds - from) / (to - from), 0, 1)
}

// Lights the destination sign while the driver is out of the bus, from the
// first step out until the door has closed behind them, and runs its words
// right to left, in the middle of the sign at STILL; blank at other times.
function poseSign({ plane, texture, wordsWidth, signWidth }, at) {
  plane.visible = at >= TIMELINE.stepOut[0] && at < TIMELINE.doorClose[1]
  const middle = (wordsWidth - signWidth) / 2
  texture.offset.x = (middle + (at - STILL) * SIGN_SPEED) / (wordsWidth + signWidth)
}

// Puts a rider where their keyframes have them `at` seconds into the loop:
// walking or turning evenly from one keyframe to the next, standing still
// before the first and after the last, and hidden while aboard.
function poseRider({ figure, keys, aboard: [from, to] }, at) {
  figure.visible = at < from || at >= to
  const next = keys.findIndex(([seconds]) => seconds > at)
  if (next <= 0) {
    const [, x, z, degrees] = next === 0 ? keys[0] : keys.at(-1)
    stand(figure, x, z, degrees)
    return
  }
  const [t0, x0, z0, d0] = keys[next - 1]
  const [t1, x1, z1, d1] = keys[next]
  const p = (at - t0) / (t1 - t0)
  stand(figure, THREE.MathUtils.lerp(x0, x1, p), THREE.MathUtils.lerp(z0, z1, p), THREE.MathUtils.lerp(d0, d1, p))
}

function stand(figure, x, z, degrees) {
  figure.position.set(x, 0, z)
  figure.rotation.y = THREE.MathUtils.degToRad(degrees)
}

const easeIn = (p) => p ** 2
const easeOut = (p) => 1 - (1 - p) ** 2
const easeInOut = (p) => (p < 0.5 ? 2 * p * p : 1 - (-2 * p + 2) ** 2 / 2)

// Both shots look from the same angle; each frames a box in world units.
const VIEW = { azimuth: 28, elevation: 30 }

// The whole block, all three groups: the block itself, and the top of the bus
// where it comes in at the left edge, the highest point anything reaches in
// the shot. (A box up to the height of the bus would frame its empty corner
// above the far left of the block.)
export function wideCamera() {
  return orthographic({ aspect: WIDE.width / WIDE.height, frame: [[-15, -1, -6.5], [15, 0, 6.5]], also: [[-15, 3.1, -2.8]], margin: 0.8, ...VIEW })
}

// The terminal alone: the bus and its driver on the pavement beside it. It
// keeps where it stands, for aimNarrowCamera() to move it from.
export function narrowCamera() {
  const camera = orthographic({ aspect: NARROW.width / NARROW.height, frame: [[-6.1, 0, -2.85], [6.2, 3.45, 1.4]], margin: 0.6, ...VIEW })
  camera.userData.terminal = camera.position.clone()
  return camera
}

// The narrow framing is too close for the terminal and the stop at once, so
// its camera moves along TO_THE_STOP, at the same angle and scale, which also
// frames more of the pavement in front, where the riders wait. It goes with
// the bus as it pulls up to the stop, in step with it, as a camera running
// ahead would push the bus up against the top edge, and comes back over
// BACK_TO_TERMINAL at the start of the next lap, as the next bus comes in.
const TO_THE_STOP = new THREE.Vector3(9.1, 0, 1.2)
const BACK_TO_TERMINAL = [0, 1.2]

// Moves the narrow camera to where it looks `seconds` into the animation,
// counted round the loop: on the terminal at STILL, and on the stop from the
// time the bus has pulled up there until the next lap begins.
export function aimNarrowCamera(camera, seconds) {
  const at = THREE.MathUtils.euclideanModulo(seconds, CYCLE)
  const phase = (span) => easeInOut(progress(at, span))
  camera.position.copy(camera.userData.terminal).addScaledVector(TO_THE_STOP, 1 - phase(BACK_TO_TERMINAL) + phase(TIMELINE.pullUp))
  camera.updateMatrixWorld()
}

// The export keeps the drawing buffer to read it back as a file; the home
// page does not need to.
export function createRenderer(canvas, { preserveDrawingBuffer = false } = {}) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer })
  renderer.setClearColor(0x000000, 0)
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFShadowMap
  renderer.localClippingEnabled = true
  return renderer
}

// Renders one frame at exactly width × height pixels whatever the screen's
// pixel ratio, so the canvas holds the image an export saves.
export function renderFrame(renderer, scene, camera, width, height) {
  renderer.setPixelRatio(1)
  renderer.setSize(width, height, false)
  renderer.render(scene, camera)
}

// An orthographic camera looking from `azimuth` degrees round from the front
// (+z) towards +x and `elevation` degrees above the ground. It frames the
// world box `frame` [min, max] and the points `also` with `margin` world
// units to spare, widening the other side to keep `aspect`.
function orthographic({ aspect, frame: [min, max], also = [], margin, azimuth, elevation }) {
  const middle = new THREE.Vector3(...min).add(new THREE.Vector3(...max)).multiplyScalar(0.5)
  const direction = new THREE.Vector3().setFromSphericalCoords(1, THREE.MathUtils.degToRad(90 - elevation), THREE.MathUtils.degToRad(azimuth))
  const camera = new THREE.OrthographicCamera()
  camera.position.copy(middle).addScaledVector(direction, 80)
  camera.lookAt(middle)
  camera.updateMatrixWorld()

  const corners = [min[0], max[0]].flatMap((x) => [min[1], max[1]].flatMap((y) => [min[2], max[2]].map((z) => new THREE.Vector3(x, y, z))))
  const points = [...corners, ...also.map((point) => new THREE.Vector3(...point))]
  const seen = new THREE.Box3().setFromPoints(points.map((point) => point.applyMatrix4(camera.matrixWorldInverse)))
  const center = seen.getCenter(new THREE.Vector3())
  let halfWidth = (seen.max.x - seen.min.x) / 2 + margin
  let halfHeight = (seen.max.y - seen.min.y) / 2 + margin
  if (halfWidth / halfHeight < aspect) halfWidth = halfHeight * aspect
  else halfHeight = halfWidth / aspect

  Object.assign(camera, { left: center.x - halfWidth, right: center.x + halfWidth, top: center.y + halfHeight, bottom: center.y - halfHeight, near: 1, far: 200 })
  camera.updateProjectionMatrix()
  return camera
}

function addLights(scene, shadowMapSize) {
  scene.add(new THREE.HemisphereLight(0xffffff, SLATE_300, Math.PI * 0.65))

  const sun = new THREE.DirectionalLight(0xffffff, Math.PI * 0.45)
  sun.position.set(-8, 20, 12)
  sun.castShadow = true
  sun.shadow.mapSize.set(shadowMapSize, shadowMapSize)
  Object.assign(sun.shadow.camera, { left: -24, right: 24, top: 24, bottom: -24, near: 1, far: 60 })
  sun.shadow.camera.updateProjectionMatrix()
  sun.shadow.radius = 3
  sun.shadow.bias = -0.0004
  sun.shadow.normalBias = 0.02
  scene.add(sun)
}

// The cut-out block, 30 by 13: the ground, and the road along x with its lane
// line. The road runs from z -5.8 to 0.3; the pavement in front of it is where
// people stand.
function ground() {
  const group = new THREE.Group()
  group.add(box([30, 1, 13], [0, -1, 0], SLATE_100))
  group.add(box([30, 0.04, 6.1], [0, 0, -2.75], SLATE_300))
  for (let x = -13.5; x < 15; x += 3.6) group.add(box([1.8, 0.02, 0.16], [x, 0.04, -3.6], SLATE_100))
  return group
}

// The plants on the kerb side of the pavement, which stay put: three street
// trees and, in front of the bus, two planters lower than its windows. Seen
// from the camera's angle a thing on the pavement covers whatever lies behind
// it at about the same 0.883x − 0.469z, so the trees keep clear of the driver
// and the front door at the terminal (x 3.4 to 5.6), of the stop, its riders
// and their way to the bus (x 9.3 to 13.8) and of the office.
function greenery() {
  const group = new THREE.Group()
  for (const x of [-7.2, 7.5, 14.0]) group.add(tree([x, 0.9]))
  for (const x of [-3.0, 1.8]) {
    group.add(box([1.5, 0.32, 0.62], [x, 0, 0.75], SLATE_300, { radius: 0.06 }))
    for (const dx of [-0.45, 0, 0.45]) group.add(ball(0.3, [x + dx, 0.18, 0.75], GREEN_600))
  }
  return group
}

// A street tree standing in a pit at `at` [x, z]: a slate trunk and a crown
// of two balls, the second smaller and off to one side so that it reads as
// leaves rather than a lollipop.
function tree([x, z]) {
  const trunk = 1.0
  const crown = 0.75
  const group = new THREE.Group()
  group.add(box([0.9, 0.04, 0.9], [x, 0, z], SLATE_300))
  group.add(cylinder(0.11, trunk, [x, 0, z], SLATE_600))
  group.add(ball(crown, [x, trunk - crown * 0.35, z], GREEN_600))
  group.add(ball(crown * 0.62, [x + crown * 0.55, trunk - crown * 0.45, z + crown * 0.3], GREEN_600))
  return group
}

// The dispatch office on the pavement, cut open at the top like the block
// itself so that the room shows: a wide window in the wall facing the street,
// a door towards the bus, a desk with a screen under the duty board on the
// far wall, the station master at the desk, pointing at the board, and a
// Samoyed sitting on the floor behind the window, which never moves.
// Its origin is the ground in the middle of the room.
function dispatchOffice() {
  const group = new THREE.Group()
  const height = 2.4
  const opening = { left: -2.0, right: 1.6, bottom: 0.8, top: 2.15 }
  const door = { from: -0.7, to: 0.5, top: 2.05 }

  group.add(box([5.0, 0.02, 3.6], [0, 0, 0], SLATE_300))
  group.add(box([5.4, height, 0.2], [0, 0, -1.9], SLATE_100))
  group.add(box([0.2, height, 4.0], [-2.6, 0, 0], SLATE_100))

  // The wall towards the bus, built round its closed door.
  group.add(box([0.2, height, door.from + 2.0], [2.6, 0, (door.from - 2.0) / 2], SLATE_100))
  group.add(box([0.2, height, 2.0 - door.to], [2.6, 0, (door.to + 2.0) / 2], SLATE_100))
  group.add(box([0.2, height - door.top, door.to - door.from], [2.6, door.top, (door.from + door.to) / 2], SLATE_100))
  group.add(box([0.08, door.top, door.to - door.from], [2.62, 0, (door.from + door.to) / 2], TEAL_700))
  group.add(box([0.04, 0.06, 0.16], [2.68, 1.0, door.to - 0.18], SLATE_800))

  // The wall facing the street, built round its window, with a light frame and sill.
  group.add(box([5.4, opening.bottom, 0.2], [0, 0, 1.9], SLATE_100))
  group.add(box([5.4, height - opening.top, 0.2], [0, opening.top, 1.9], SLATE_100))
  group.add(box([opening.left + 2.7, opening.top - opening.bottom, 0.2], [(opening.left - 2.7) / 2, opening.bottom, 1.9], SLATE_100))
  group.add(box([2.7 - opening.right, opening.top - opening.bottom, 0.2], [(opening.right + 2.7) / 2, opening.bottom, 1.9], SLATE_100))
  const width = opening.right - opening.left
  group.add(box([width + 0.12, 0.06, 0.32], [(opening.left + opening.right) / 2, opening.bottom - 0.04, 1.92], SLATE_300))
  group.add(box([width, 0.04, 0.22], [(opening.left + opening.right) / 2, opening.top - 0.04, 1.9], SLATE_300))
  for (const x of [opening.left, opening.right]) group.add(box([0.04, opening.top - opening.bottom, 0.22], [x, opening.bottom, 1.9], SLATE_300))

  group.add(desk([0.2, -1.45]))
  group.add(dutyBoard([0.2, 1.2, -1.8]))
  group.add(poster([-1.95, 1.65, -1.79]))

  const { figure: master } = person(SLATE_600, { cap: true, pointing: true })
  master.position.set(0.5, 0, -0.5)
  master.rotation.y = Math.PI
  group.add(master)

  // Back from the window far enough to show over the sill, but not so far
  // that the wall above the window hides its head; it faces the bus, half
  // turned towards the street.
  const dog = samoyed()
  dog.position.set(-0.9, 0, 0.4)
  dog.rotation.y = -0.5
  group.add(dog)
  return group
}

// A desk against the far wall at `at` [x, z] with a screen on it.
function desk([x, z]) {
  const group = new THREE.Group()
  group.add(box([3.0, 0.06, 0.7], [x, 0.72, z], SLATE_100))
  for (const dx of [-1.42, 1.42]) for (const dz of [-0.3, 0.3]) group.add(box([0.06, 0.72, 0.06], [x + dx, 0, z + dz], SLATE_800))
  group.add(box([0.6, 0.32, 0.05], [x - 0.8, 0.86, z - 0.15], SLATE_800))
  group.add(box([0.1, 0.08, 0.1], [x - 0.8, 0.78, z - 0.15], SLATE_800))
  return group
}

// The duty board: a dark board on the wall at `at` (its bottom middle) with a
// grid of slate cells and a few amber ones. No text.
function dutyBoard([x, y, z]) {
  const group = new THREE.Group()
  const columns = 7
  const rows = 4
  const amber = new Set(["0,2", "1,5", "2,0", "3,4"])
  group.add(box([3.0, 1.0, 0.05], [x, y, z + 0.025], SLATE_800))
  for (let row = 0; row < rows; row++) {
    for (let column = 0; column < columns; column++) {
      const color = amber.has(`${row},${column}`) ? AMBER_400 : SLATE_300
      group.add(box([0.34, 0.17, 0.03], [x - 1.2 + column * 0.4, y + 0.07 + row * 0.23, z + 0.065], color))
    }
  }
  return group
}

// The fonts for the characters on the poster and the destination sign.
const CHINESE_FONTS = "'PingFang TC', 'Heiti TC', 'Microsoft JhengHei', 'Noto Sans TC', sans-serif"

// A poster on the far wall beside the duty board, centred at `at`: a rough
// likeness of the 洋流 poster, orange with a white band down the middle and
// the two characters in black, drawn on a canvas when the scene is built. The
// characters come from whatever font the browser has, so their shapes differ
// a little from device to device; the static images are exported with the
// development machine's. Its colours are the poster's own, not the palette's.
function poster([x, y, z]) {
  const canvas = document.createElement("canvas")
  canvas.width = 300
  canvas.height = 400
  const context = canvas.getContext("2d")
  context.fillStyle = "#ef5a2b"
  context.fillRect(0, 0, 300, 400)
  context.fillStyle = "#ffffff"
  context.fillRect(95, 0, 110, 400)
  context.fillStyle = "#111111"
  context.font = `900 175px ${CHINESE_FONTS}`
  context.textAlign = "center"
  context.textBaseline = "middle"
  context.fillText("洋", 150, 110)
  context.fillText("流", 150, 290)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  const sheet = new THREE.Mesh(new THREE.PlaneGeometry(0.75, 1.0), new THREE.MeshLambertMaterial({ map: texture }))
  sheet.position.set(x, y, z)
  sheet.receiveShadow = true
  return sheet
}

// A Samoyed sitting up, facing +x with its feet at the origin, about half as
// tall as a person: white haunches, a chest leaning back under a thick ruff,
// two straight forelegs, a plumed tail curled over its back and the head.
function samoyed() {
  const group = new THREE.Group()
  group.add(ball(0.21, [-0.13, 0, 0], SLATE_100))
  const chest = box([0.26, 0.42, 0.34], [0.03, 0.1, 0], SLATE_100, { radius: 0.13 })
  chest.rotation.z = -0.3
  group.add(chest)
  group.add(ball(0.17, [0.1, 0.32, 0], SLATE_100))
  for (const z of [-0.08, 0.08]) group.add(box([0.09, 0.4, 0.09], [0.15, 0, z], SLATE_100, { radius: 0.04 }))
  group.add(ball(0.13, [-0.33, 0.24, 0.1], SLATE_100))
  group.add(dogHead([0.16, 0.62, 0]))
  return group
}

// The Samoyed's head, facing +x and centred at `at`: a white ball with a
// short muzzle, a black nose, two dot eyes like the people's and two pricked
// ears, each a four-sided cone centred where it sits.
function dogHead([x, y, z]) {
  const head = new THREE.Group()
  head.position.set(x, y, z)
  const radius = 0.15
  head.add(ball(radius, [0, -radius, 0], SLATE_100))
  head.add(box([0.15, 0.1, 0.13], [0.11, -0.1, 0], SLATE_100, { radius: 0.05 }))
  head.add(ball(0.03, [0.185, -0.075, 0], SLATE_800))
  for (const side of [-1, 1]) head.add(ball(0.022, [0.124, 0.003, side * 0.071], SLATE_800))
  for (const side of [-1, 1]) {
    const ear = new THREE.Mesh(new THREE.ConeGeometry(0.055, 0.13, 4), material(SLATE_100))
    ear.position.set(-0.02, 0.167, side * 0.08)
    ear.rotation.set(side * 0.3, Math.PI / 4, 0)
    ear.castShadow = true
    ear.receiveShadow = true
    head.add(ear)
  }
  return head
}

// The head of every person: its radius and the height of its centre.
const HEAD = { radius: 0.21, y: 1.41 }

// A person facing +z with their feet at the origin, rounded rather than
// boxy: dark trousers on two short legs, `clothes` on a soft body and on
// capsule arms, a round head about a quarter of their height with dark hair
// over its top and back and two dot eyes, and, for the station master, a cap
// and a right arm raised to point ahead. No blush and one hairstyle for all.
// Returns the figure with its two arms, which pose() raises for the driver's
// stretch.
function person(clothes, { cap = false, pointing = false } = {}) {
  const group = new THREE.Group()
  for (const x of [-0.1, 0.1]) group.add(box([0.17, 0.62, 0.22], [x, 0, 0], SLATE_800, { radius: 0.08 }))
  group.add(box([0.54, 0.62, 0.36], [0, 0.56, 0], clothes, { radius: 0.17 }))
  const arms = [arm(0.32, clothes, 0), arm(-0.32, clothes, pointing ? -130 : 0)]
  group.add(...arms)
  group.add(ball(HEAD.radius, [0, HEAD.y - HEAD.radius, 0], SKIN))
  group.add(hair())
  for (const x of [-0.075, 0.075]) group.add(ball(0.03, [x, HEAD.y - 0.02, HEAD.radius * 0.93], SLATE_800))
  if (cap) {
    const brim = HEAD.y + HEAD.radius * 0.72
    group.add(cylinder(0.215, 0.08, [0, brim, 0], SLATE_800))
    group.add(box([0.3, 0.03, 0.16], [0, brim, HEAD.radius * 0.8], SLATE_800))
  }
  return { figure: group, arms }
}

// An arm hanging from the shoulder at `x`, turned forward by `degrees`: a
// capsule long enough for a stretch to lift the hands over the head.
function arm(x, clothes, degrees) {
  const shoulder = new THREE.Group()
  shoulder.position.set(x, 1.12, 0)
  shoulder.rotation.x = THREE.MathUtils.degToRad(degrees)
  shoulder.add(place(new THREE.Mesh(new THREE.CapsuleGeometry(0.07, 0.42, 4, 12), material(clothes)), [0, -0.56, 0], 0.56))
  return shoulder
}

// The hair: a half shell a little larger than the head over its top, tipped
// back so that it covers the back of the head and leaves the face.
function hair() {
  const shell = new THREE.Mesh(new THREE.SphereGeometry(HEAD.radius * 1.07, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), material(SLATE_800))
  shell.position.set(0, HEAD.y, 0)
  shell.rotation.x = -0.45
  shell.castShadow = true
  shell.receiveShadow = true
  return shell
}

// A generic low-floor city bus heading +x with its door side towards +z: a
// white body with a teal band under the windows, and no operator's livery,
// route number or emblem. Its destination sign is blank except while the
// driver is out, when it runs 暫停服務 (out of service). Its origin is the
// ground under its middle. Returns the bus with the two leaves of its front
// door, which pose() opens: the front one swings out, the rear one folds into
// the bus; and the lit face of its sign, which pose() lights and runs.
function bus() {
  const group = new THREE.Group()
  const length = 12
  const width = 2.5
  const floor = 0.35
  const roof = 3.1
  const side = width / 2 + 0.01
  const front = length / 2 + 0.01
  const band = [1.18, 1.4]

  group.add(box([length, roof - floor, width], [0, floor, 0], SLATE_100, { radius: 0.18 }))
  for (const x of [-3.9, 3.0]) for (const z of [-1.0, 1.0]) group.add(wheel(x, z))
  group.add(box([3.6, 0.32, 1.7], [-1.8, roof - 0.02, 0], SLATE_300, { radius: 0.1 }))

  // The door side: the band, broken by the doors, then the windows, the middle
  // door closed and the front door open.
  for (const [from, to] of [[-5.8, 0.0], [1.5, 4.45], [5.55, 5.8]]) group.add(panel([from, to], band, side, TEAL_700))
  for (const [from, to] of [[-5.6, -3.95], [-3.8, -2.15], [-2.0, -0.35], [1.85, 3.0], [3.15, 4.25]]) {
    group.add(panel([from, to], [1.55, 2.8], side))
  }
  group.add(panel([0.0, 0.7], [0.45, 2.8], side))
  group.add(panel([0.78, 1.5], [0.45, 2.8], side))
  group.add(panel([4.45, 5.55], [0.4, 2.85], side))
  const frontLeaf = doorLeaf(5.55, 0.42, side, -1)
  const rearLeaf = doorLeaf(4.45, 0.42, side, 1)
  group.add(frontLeaf, rearLeaf)

  // The front: the band, windscreen, the destination sign with its lit face
  // just in front, bumper and lamps.
  group.add(box([0.04, band[1] - band[0], 2.1], [front, band[0], 0], TEAL_700))
  group.add(box([0.04, 1.2, 2.1], [front, 1.45, 0], SLATE_800))
  group.add(box([0.04, 0.28, 1.9], [front, 2.74, 0], SLATE_800))
  const sign = signFace(1.9, 0.28)
  sign.plane.position.set(front + 0.025, 2.88, 0)
  sign.plane.rotation.y = Math.PI / 2
  group.add(sign.plane)
  group.add(box([0.14, 0.3, width], [front, floor, 0], SLATE_800, { radius: 0.05 }))
  for (const z of [-0.85, 0.85]) group.add(box([0.06, 0.18, 0.42], [front, 0.78, z], SLATE_300))
  return { group, frontLeaf, rearLeaf, sign }
}

// A wheel standing a little proud of the body side at z = ±1.25, with its hub.
function wheel(x, z) {
  const group = new THREE.Group()
  group.add(cylinder(0.52, 0.32, [0, 0, 0], SLATE_800))
  group.add(cylinder(0.2, 0.02, [0, 0.32, 0], SLATE_300))
  group.rotation.x = Math.sign(z) * Math.PI / 2
  group.position.set(x, 0.52, z)
  return group
}

// A pane on the door side, dark unless `color` says otherwise, from x `from`
// to `to` and y `bottom` to `top`.
function panel([from, to], [bottom, top], side, color = SLATE_800) {
  return box([to - from, top - bottom, 0.04], [(from + to) / 2, bottom, side], color)
}

// A leaf of the front door, hinged on the door side at `hinge` and reaching
// `towards` (+1 or -1 along x) to the middle of the doorway; closed until
// pose() turns it. (Swung out, the rear leaf would face the camera edge on and
// read as a pole, so it folds into the bus instead.)
function doorLeaf(hinge, bottom, side, towards) {
  const pivot = new THREE.Group()
  pivot.position.set(hinge, 0, side)
  pivot.add(box([0.55, 2.4, 0.06], [towards * 0.275, bottom, 0.03], SLATE_100))
  pivot.add(box([0.38, 1.5, 0.02], [towards * 0.275, bottom + 0.75, 0.07], SLATE_800))
  return pivot
}

// The words the destination sign runs while the driver is out of the bus,
// and how: SIGN_FONT pixels high on a strip SIGN_PIXELS tall, moving right to
// left at SIGN_SPEED pixels a second, three characters a second.
const OUT_OF_SERVICE = "暫停服務"
const SIGN_PIXELS = 64
const SIGN_FONT = 50
const SIGN_SPEED = 150

// The lit face of the destination sign, `width` by `height`, facing +z and
// hidden until poseSign() lights it. It shows a sign-wide stretch of a strip
// drawn on a canvas, the words in amber on the sign's dark followed by a gap
// as wide as the sign, so that the words have left before they come round
// again; poseSign() slides the stretch along the strip, which repeats. It
// ignores the scene's lights, as a lit sign makes its own.
function signFace(width, height) {
  const canvas = document.createElement("canvas")
  const context = canvas.getContext("2d")
  const font = `900 ${SIGN_FONT}px ${CHINESE_FONTS}`
  context.font = font
  const words = context.measureText(OUT_OF_SERVICE)
  const wordsWidth = Math.ceil(words.width)
  const signWidth = Math.round((SIGN_PIXELS * width) / height)
  // Sizing the canvas clears it and resets the context, font included.
  canvas.width = wordsWidth + signWidth
  canvas.height = SIGN_PIXELS
  context.fillStyle = new THREE.Color(SLATE_800).getStyle()
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.font = font
  context.fillStyle = new THREE.Color(AMBER_400).getStyle()
  // Centred on the characters' own height, which differs from font to font.
  context.fillText(OUT_OF_SERVICE, 0, (SIGN_PIXELS + words.actualBoundingBoxAscent - words.actualBoundingBoxDescent) / 2)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = THREE.RepeatWrapping
  texture.repeat.x = signWidth / canvas.width
  // Seen at a slant, the words blur into a bar with plain mipmaps; filtering
  // anisotropically keeps them clearer, without the shimmer of the sharper
  // filtering that skips mipmaps. three.js caps it at what the GPU supports.
  texture.anisotropy = 16
  const plane = new THREE.Mesh(new THREE.PlaneGeometry(width, height), new THREE.MeshBasicMaterial({ map: texture }))
  plane.visible = false
  return { plane, texture, wordsWidth, signWidth }
}

// Riders waiting at the stop for the bus's next trip, turned more or less
// towards it, their clothes alternating with the station master's and the
// driver's. Once the bus has pulled up, each sets off for the front door at
// `boards` seconds, nearest first, by way of `via` round the pole of the
// stop, and gets on after the one before. When the bus has gone, a new rider
// walks in at `arrives` seconds from beyond the right edge to the same place
// and turns the same way, so that the next lap starts as this one did.
// Places are in the stop's coordinates.
const RIDERS = [
  { at: [-0.9, 1.0], degrees: -100, clothes: SLATE_600, boards: 14.2, via: [[-0.45, -0.55]], arrives: 18.4 },
  { at: [0.2, 1.5], degrees: -60, clothes: TEAL_500, boards: 13.7, via: [[0.65, 0.3]], arrives: 18.6 },
  { at: [1.3, 0.9], degrees: -35, clothes: SLATE_600, boards: 13.4, via: [], arrives: 18.8 },
]
const ENTER_X = 4.2 // a rider beyond the right edge of the block, in the stop's coordinates
const WALKING_SPEED = 2.5 // world units a second
const TURN_SECONDS = 0.15

// The riders, each with their keyframes and the span they spend aboard, cut
// at the edges of the block like the bus. They are posed by pose().
function riders() {
  return RIDERS.map(({ at, degrees, clothes, boards, via, arrives }) => {
    const { figure } = person(clothes)
    clipToBlock(figure)
    const boarding = walk(boards, degrees, [at, ...via, KERBSIDE, ABOARD])
    const aboard = boarding.at(-1)[0]
    if (aboard > TIMELINE.doorCloseAtStop[0]) throw new Error(`a rider gets on at ${aboard} s, after the door starts closing at ${TIMELINE.doorCloseAtStop[0]} s`)
    const arriving = walk(arrives, -90, [[ENTER_X, at[1]], at], degrees)
    if (arriving.at(-1)[0] > CYCLE) throw new Error(`a rider reaches the stop at ${arriving.at(-1)[0]} s, after the lap ends at ${CYCLE} s`)
    return { figure, keys: [...boarding, ...arriving], aboard: [aboard, arrives] }
  })
}

// The keyframes [seconds, x, z, degrees] of a figure standing at the first of
// `points`, facing `degrees`, until `from` seconds, then walking through the
// rest at WALKING_SPEED, turning on the spot towards each leg first and, when
// `face` is given, to face that way at the end.
function walk(from, degrees, points, face) {
  let [x, z] = points[0]
  let seconds = from
  let heading = degrees
  const keys = [[seconds, x, z, heading]]
  for (const [toX, toZ] of points.slice(1)) {
    heading = nearestTurn(heading, THREE.MathUtils.radToDeg(Math.atan2(toX - x, toZ - z)))
    seconds += TURN_SECONDS
    keys.push([seconds, x, z, heading])
    seconds += Math.hypot(toX - x, toZ - z) / WALKING_SPEED
    x = toX
    z = toZ
    keys.push([seconds, x, z, heading])
  }
  if (face !== undefined) keys.push([seconds + TURN_SECONDS, x, z, nearestTurn(heading, face)])
  return keys
}

// `degrees` give or take whole turns, whichever is nearest `from`, so that a
// figure turns the short way round.
function nearestTurn(from, degrees) {
  return degrees + 360 * Math.round((from - degrees) / 360)
}

// The stop: a pole with its sign facing the street and the camera, no text.
function stopSign() {
  const group = new THREE.Group()
  group.add(cylinder(0.22, 0.08, [0, 0, 0], SLATE_800))
  group.add(cylinder(0.07, 3.7, [0, 0, 0], SLATE_800))
  group.add(box([1.1, 1.5, 0.08], [0, 2.1, 0.1], AMBER_400, { radius: 0.03 }))
  group.add(box([1.1, 0.24, 0.1], [0, 3.36, 0.1], SLATE_800))
  return group
}

// A box of `size` [x, y, z] whose bottom middle sits at `at` [x, y, z].
function box(size, at, color, { radius = 0 } = {}) {
  const [width, height, depth] = size
  const geometry = radius > 0 ? new RoundedBoxGeometry(width, height, depth, 3, radius) : new THREE.BoxGeometry(width, height, depth)
  return place(new THREE.Mesh(geometry, material(color)), at, height)
}

// An upright cylinder whose bottom middle sits at `at`.
function cylinder(radius, height, at, color) {
  return place(new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, height, 28), material(color)), at, height)
}

// A ball whose bottom sits at `at`.
function ball(radius, at, color) {
  return place(new THREE.Mesh(new THREE.SphereGeometry(radius, 24, 16), material(color)), at, radius * 2)
}

function place(mesh, [x, y, z], height) {
  mesh.position.set(x, y + height / 2, z)
  mesh.castShadow = true
  mesh.receiveShadow = true
  return mesh
}

const materials = new Map()

function material(color) {
  if (!materials.has(color)) materials.set(color, new THREE.MeshLambertMaterial({ color }))
  return materials.get(color)
}

// Gives every mesh of `object` a copy of its material that is cut, shadow
// included, beyond the left and right edges of the block.
function clipToBlock(object) {
  object.traverse((child) => {
    if (child.isMesh) child.material = clippedMaterial(child.material)
  })
}

const clippedMaterials = new Map()

function clippedMaterial(source) {
  if (!clippedMaterials.has(source)) {
    clippedMaterials.set(source, Object.assign(source.clone(), { clippingPlanes: BLOCK_EDGES, clipShadows: true }))
  }
  return clippedMaterials.get(source)
}
