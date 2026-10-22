// The hero illustration of the home page: a three.js scene shared by the home
// page, which plays its animation once, and by the export page in tools/hero,
// which saves the last frame as the WebP files the home page falls back to
// (app/assets/images/home-hero-wide.webp and home-hero-tall.webp).
//
// A bus drives into the terminal and stops, the front door opens and the
// driver steps out to rest beside it; on the left the dispatch office's
// window, on the right the stop with riders waiting. Orthographic cameras at
// a fixed angle from above, one directional light and a hemisphere light,
// flat Lambert materials and a transparent background.
import * as THREE from "three"
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js"

// The route page's palette (Tailwind v4, approximate hex), and nothing else.
const SLATE_100 = 0xf1f5f9 // the ground, the bus body, the office walls and other light parts
const SLATE_300 = 0xcbd5e1 // the road, heads, lamps, the roof unit and the board's cells
const SLATE_600 = 0x475569 // clothes
const SLATE_800 = 0x1e293b // windows and dark parts
const TEAL_500 = 0x14b8a6 // clothes
const TEAL_700 = 0x0f766e // the band on the bus and the office door
const AMBER_400 = 0xfbbf24 // the one accent: the stop sign and a few cells of the board

// The two framings' sizes in pixels. The static images are exported at these
// sizes (tools/hero/export.js) and the cameras take their aspect from them;
// over budget, the export drops to 1600×900 and 900×900, the same aspects.
export const WIDE = { width: 2048, height: 1152 }
export const TALL = { width: 1170, height: 1170 }

// Everything beyond the left edge of the block is cut away, so the bus drives
// in out of the cut rather than over the transparent background.
const BLOCK_EDGE = new THREE.Plane(new THREE.Vector3(1, 0, 0), 15)

// Returns the scene, its three groups, left to right (the dispatch office
// window, the terminal with the bus and its driver, and the stop), and the
// parts the animation moves, posed at the end of the animation. The export
// renders shadows from a 4096 map; the home page asks for a smaller one.
export function buildScene({ shadowMapSize = 4096 } = {}) {
  const scene = new THREE.Scene()
  addLights(scene, shadowMapSize)
  scene.add(ground())

  const dispatch = new THREE.Group()
  dispatch.add(dispatchOffice())
  dispatch.position.set(-11.4, 0, 3.3)

  const { group: busGroup, frontLeaf, rearLeaf } = bus()
  clipToBlock(busGroup)
  const driver = person(TEAL_500)
  const terminal = new THREE.Group()
  terminal.add(busGroup, driver)
  terminal.position.set(0, 0, -1.55)

  const stop = new THREE.Group()
  stop.add(stopSign(), ...riders())
  stop.position.set(11.4, 0, 1.3)

  scene.add(dispatch, terminal, stop)
  const parts = { bus: busGroup, frontLeaf, rearLeaf, driver }
  pose(parts, 1)
  return { scene, dispatch, terminal, stop, parts }
}

// The animation, in seconds: the bus drives in from beyond the left edge of
// the block and stops, the front door opens, the driver steps out of it,
// walks to the side of the bus and leans back against it.
export const DURATION = 5.5
const TIMELINE = { drive: [0, 3.0], door: [3.0, 3.8], stepOut: [3.8, 4.6], walk: [4.6, 5.2], lean: [5.2, 5.4] }
const BUS_START_X = -22 // the whole bus beyond the left edge of the block
const FRONT_LEAF_DEGREES = 62 // swung out
const REAR_LEAF_DEGREES = 90 // folded into the bus, then out of sight
const DOORWAY = { x: 4.9, z: 0.9 } // inside the bus, hidden by its body
const RESTING = { x: 4.15, z: 1.63, lean: -0.12 } // between the front wheel and the open door

// Puts the moving parts where they are `t` (0 to 1) of the way through the
// animation; pose(parts, 1) is the still the site serves as images.
export function pose({ bus, frontLeaf, rearLeaf, driver }, t) {
  const seconds = THREE.MathUtils.clamp(t, 0, 1) * DURATION
  bus.position.x = THREE.MathUtils.lerp(BUS_START_X, 0, easeOut(progress(seconds, TIMELINE.drive)))

  const door = easeInOut(progress(seconds, TIMELINE.door))
  frontLeaf.rotation.y = THREE.MathUtils.degToRad(FRONT_LEAF_DEGREES * door)
  rearLeaf.rotation.y = THREE.MathUtils.degToRad(REAR_LEAF_DEGREES * door)
  rearLeaf.visible = door < 1

  driver.visible = seconds >= TIMELINE.stepOut[0]
  driver.position.set(
    THREE.MathUtils.lerp(DOORWAY.x, RESTING.x, easeInOut(progress(seconds, TIMELINE.walk))),
    0,
    THREE.MathUtils.lerp(DOORWAY.z, RESTING.z, easeInOut(progress(seconds, TIMELINE.stepOut))),
  )
  driver.rotation.x = RESTING.lean * easeInOut(progress(seconds, TIMELINE.lean))
}

// How far `seconds` is through the span [from, to], from 0 to 1.
function progress(seconds, [from, to]) {
  return THREE.MathUtils.clamp((seconds - from) / (to - from), 0, 1)
}

const easeOut = (p) => 1 - (1 - p) ** 2
const easeInOut = (p) => (p < 0.5 ? 2 * p * p : 1 - (-2 * p + 2) ** 2 / 2)

// Both shots look from the same angle; each frames a box in world units.
const VIEW = { azimuth: 28, elevation: 30 }

// The whole block, all three groups.
export function wideCamera() {
  return orthographic({ aspect: WIDE.width / WIDE.height, frame: [[-15, -1, -6.5], [15, 3.8, 6.5]], margin: 0.8, ...VIEW })
}

// The terminal alone: the bus and its driver on the pavement beside it.
export function tallCamera() {
  return orthographic({ aspect: TALL.width / TALL.height, frame: [[-6.1, 0, -2.85], [6.2, 3.45, 1.4]], margin: 0.6, ...VIEW })
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
// world box `frame` [min, max] with `margin` world units to spare, widening
// the other side to keep `aspect`.
function orthographic({ aspect, frame: [min, max], margin, azimuth, elevation }) {
  const middle = new THREE.Vector3(...min).add(new THREE.Vector3(...max)).multiplyScalar(0.5)
  const direction = new THREE.Vector3().setFromSphericalCoords(1, THREE.MathUtils.degToRad(90 - elevation), THREE.MathUtils.degToRad(azimuth))
  const camera = new THREE.OrthographicCamera()
  camera.position.copy(middle).addScaledVector(direction, 80)
  camera.lookAt(middle)
  camera.updateMatrixWorld()

  const corners = [min[0], max[0]].flatMap((x) => [min[1], max[1]].flatMap((y) => [min[2], max[2]].map((z) => new THREE.Vector3(x, y, z))))
  const seen = new THREE.Box3().setFromPoints(corners.map((corner) => corner.applyMatrix4(camera.matrixWorldInverse)))
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

// The dispatch office on the pavement, cut open at the top like the block
// itself so that the room shows: a wide window in the wall facing the street,
// a door towards the bus, a desk with a screen under the duty board on the
// far wall, and the station master at the desk, pointing at the board.
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

  const master = person(SLATE_600, { cap: true, pointing: true })
  master.position.set(0.5, 0, -0.5)
  master.rotation.y = Math.PI
  group.add(master)
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

// A person built from blocks, facing +z with their feet at the origin and no
// face: dark trousers, `clothes` on the body and arms, a slate head with dark
// hair over its top and back, and, for the station master, a cap and a right
// arm raised to point ahead.
function person(clothes, { cap = false, pointing = false } = {}) {
  const group = new THREE.Group()
  for (const x of [-0.11, 0.11]) group.add(box([0.18, 0.84, 0.24], [x, 0, 0], SLATE_800))
  group.add(box([0.52, 0.62, 0.3], [0, 0.82, 0], clothes, { radius: 0.06 }))
  group.add(arm(0.33, clothes, 0))
  group.add(arm(-0.33, clothes, pointing ? -130 : 0))
  group.add(box([0.3, 0.32, 0.3], [0, 1.46, 0], SLATE_300, { radius: 0.08 }))
  group.add(box([0.32, 0.1, 0.32], [0, 1.72, 0], SLATE_800, { radius: 0.04 }))
  group.add(box([0.32, 0.26, 0.08], [0, 1.5, -0.13], SLATE_800, { radius: 0.03 }))
  if (cap) group.add(box([0.34, 0.06, 0.5], [0, 1.8, 0.07], SLATE_800, { radius: 0.02 }))
  return group
}

// An arm hanging from the shoulder at `x`, turned forward by `degrees`.
function arm(x, clothes, degrees) {
  const shoulder = new THREE.Group()
  shoulder.position.set(x, 1.42, 0)
  shoulder.rotation.x = THREE.MathUtils.degToRad(degrees)
  shoulder.add(box([0.13, 0.58, 0.17], [0, -0.58, 0], clothes, { radius: 0.05 }))
  return shoulder
}

// A generic low-floor city bus heading +x with its door side towards +z: a
// white body with a teal band under the windows, and no operator's livery,
// route number or emblem. Its origin is the ground under its middle. Returns
// the bus with the two leaves of its front door, which pose() opens: the
// front one swings out, the rear one folds into the bus.
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

  // The front: the band, windscreen, a blank destination sign, bumper and lamps.
  group.add(box([0.04, band[1] - band[0], 2.1], [front, band[0], 0], TEAL_700))
  group.add(box([0.04, 1.2, 2.1], [front, 1.45, 0], SLATE_800))
  group.add(box([0.04, 0.28, 1.9], [front, 2.74, 0], SLATE_800))
  group.add(box([0.14, 0.3, width], [front, floor, 0], SLATE_800, { radius: 0.05 }))
  for (const z of [-0.85, 0.85]) group.add(box([0.06, 0.18, 0.42], [front, 0.78, z], SLATE_300))
  return { group, frontLeaf, rearLeaf }
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

// Riders waiting at the stop for the bus's next trip, turned more or less
// towards it, their clothes alternating with the station master's and the
// driver's.
function riders() {
  return [
    { at: [-0.9, 1.0], degrees: -100, clothes: SLATE_600 },
    { at: [0.2, 1.5], degrees: -60, clothes: TEAL_500 },
    { at: [1.3, 0.9], degrees: -35, clothes: SLATE_600 },
  ].map(({ at: [x, z], degrees, clothes }) => {
    const figure = person(clothes)
    figure.position.set(x, 0, z)
    figure.rotation.y = THREE.MathUtils.degToRad(degrees)
    return figure
  })
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
// included, beyond the left edge of the block.
function clipToBlock(object) {
  object.traverse((child) => {
    if (child.isMesh) child.material = clippedMaterial(child.material)
  })
}

const clippedMaterials = new Map()

function clippedMaterial(source) {
  if (!clippedMaterials.has(source)) {
    clippedMaterials.set(source, Object.assign(source.clone(), { clippingPlanes: [BLOCK_EDGE], clipShadows: true }))
  }
  return clippedMaterials.get(source)
}
