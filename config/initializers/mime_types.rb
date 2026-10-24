# 沒標編碼的 text/plain，瀏覽器不一定用 UTF-8 解，public/robots.txt 的中文註解會變成亂碼
Rack::Mime::MIME_TYPES[".txt"] = "text/plain; charset=utf-8"
