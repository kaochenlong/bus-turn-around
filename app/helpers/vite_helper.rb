module ViteHelper
  DEV_SERVER = "http://localhost:5173".freeze
  BASE       = "/vite".freeze # 要跟 vite.config.ts 的 base 一致
  ENTRYPOINT = "app/frontend/entrypoints/application.js".freeze
  STYLESHEET = "app/frontend/stylesheets/application.css".freeze
  MANIFEST   = "public/vite/.vite/manifest.json".freeze

  # 部署後資產網址一變，Turbo 看到追蹤的標籤不同就整頁重載；
  # 少了它，新版 entry 會被併進舊的 <head>，Turbo 與 Alpine 各跑兩份
  TRACKED = { data: { turbo_track: "reload" } }.freeze

  # layout <head> 呼叫：<%= vite_assets %>
  def vite_assets(entry = ENTRYPOINT)
    if Rails.env.development?
      safe_join([
        # CSS 由 entry import 注入要等 module script 跑完，第一次繪製會沒有樣式；
        # 先放一條 <link>，dev server 看到 Accept: text/css 會直接回 CSS
        stylesheet_link("#{DEV_SERVER}#{BASE}/#{STYLESHEET}"),
        module_script("#{DEV_SERVER}#{BASE}/@vite/client"),
        module_script("#{DEV_SERVER}#{BASE}/#{entry}")
      ])
    else
      chunk = vite_manifest.fetch(entry)
      safe_join(vite_css_tags(entry) + [ module_script("#{BASE}/#{chunk["file"]}") ])
    end
  end

  private

  # shared chunk 的 CSS 不在 entry 自己的 css 欄位，要沿 imports 遞迴收集
  def vite_css_tags(entry, seen = Set.new)
    return [] unless seen.add?(entry)
    chunk = vite_manifest[entry] or return []
    tags = Array(chunk["css"]).map { |f| stylesheet_link("#{BASE}/#{f}") }
    Array(chunk["imports"]).each { |imp| tags.concat(vite_css_tags(imp, seen)) }
    tags
  end

  def vite_manifest
    @vite_manifest ||= JSON.parse(Rails.root.join(MANIFEST).read)
  end

  def module_script(src)
    tag.script(type: "module", src: src, **TRACKED)
  end

  def stylesheet_link(href)
    tag.link(rel: "stylesheet", href: href, **TRACKED)
  end
end
