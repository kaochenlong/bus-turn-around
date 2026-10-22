// Exports the last frame of the hero illustration as the WebP files the home
// page falls back to. Only tools/hero/index.html uses it.
import { TALL, WIDE, renderFrame } from "../../app/frontend/hero/scene.js"

// The files and the WebP quality. When a file is over its budget (wide 200 KB,
// tall 120 KB), lower the quality to 0.75 first, then the sizes in scene.js to
// 1600×900 and 900×900; the budget itself does not change.
export const SHOTS = {
  wide: { ...WIDE, filename: "home-hero-wide.webp" },
  tall: { ...TALL, filename: "home-hero-tall.webp" },
}
export const WEBP_QUALITY = 0.85

// Renders the frame and downloads it as `filename`, a WebP straight from the
// canvas. Rejects when the browser hands back another format, as browsers
// that cannot encode WebP do.
export function exportWebp(renderer, scene, camera, width, height, filename) {
  renderFrame(renderer, scene, camera, width, height)
  return new Promise((resolve, reject) => {
    renderer.domElement.toBlob((blob) => {
      if (blob?.type !== "image/webp") {
        reject(new Error(`${filename}: this browser encoded ${blob?.type ?? "nothing"}, not image/webp; export from Chrome`))
        return
      }
      const link = document.createElement("a")
      link.href = URL.createObjectURL(blob)
      link.download = filename
      link.click()
      setTimeout(() => URL.revokeObjectURL(link.href), 1000)
      resolve(blob)
    }, "image/webp", WEBP_QUALITY)
  })
}
