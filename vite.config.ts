import { defineConfig } from "vite"
import tailwindcss from "@tailwindcss/vite"
import FullReload from "vite-plugin-full-reload"

export default defineConfig({
  plugins: [
    tailwindcss(),
    FullReload(["config/routes.rb", "app/views/**/*", "app/components/**/*"]),
  ],
  base: "/vite/",
  // Rails 自己管 public/；關掉 vite publicDir，否則 outDir 在 public/ 內會把 Rails 靜態檔複製進去
  publicDir: false,
  build: {
    manifest: true,
    outDir: "public/vite",
    emptyOutDir: true,
    rollupOptions: { input: "app/frontend/entrypoints/application.js" },
  },
  server: {
    // localhost 與 127.0.0.1 都要放行：只放一個的話，用另一個網址開發時 module script
    // 會被 CORS 擋掉，Alpine 沒啟動，看起來像功能壞了而不是資產沒載到
    cors: { origin: ["http://localhost:3000", "http://127.0.0.1:3000"] },
    origin: "http://localhost:5173",
  },
})
