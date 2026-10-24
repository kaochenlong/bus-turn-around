require "rails_helper"

RSpec.describe "Easter eggs", type: :request do
  # The lines of the response that are neither blank nor comments.
  def rule_lines = response.body.lines.map(&:strip).reject { it.empty? || it.start_with?("#") }

  # What is inside the HTML comment on the line after the doctype, when the
  # comment closes before <html>; nil when the source does not start that way.
  def leading_comment = response.body[/\A<!DOCTYPE html>\n<!--(.*?)-->\s*<html/m, 1]

  it "robots.txt 回 200，以 UTF-8 送出，每一個非空白的行都是註解" do
    get "/robots.txt"
    expect([ response.status, response.content_type, rule_lines ]).to eq([ 200, "text/plain; charset=utf-8", [] ])
  end

  it "首頁原始碼：DOCTYPE 下一行是在 <html> 之前結束的註解，只有可見的 ASCII、空白與換行，不含 --" do
    get root_path
    expect([ leading_comment&.match?(/\A[ -~\n]*\z/), leading_comment&.include?("--") ]).to eq([ true, false ])
  end
end
