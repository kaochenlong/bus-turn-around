## Purpose

Three small touches for visitors who look under the hood, each about the rest a bus driver is owed: a comment in `robots.txt`, a bus drawn in the page source, and a `休息()` command in the browser console. They change nothing that a crawler obeys or that an ordinary visitor sees on the page.

## ADDED Requirements

### Requirement: Comment in robots.txt

`/robots.txt` SHALL contain the comment line `# 機器人也一樣，連續工作 4 小時至少休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）`. Every line of the file SHALL be a comment or blank, so that the file gives crawlers no rule and every path stays allowed. The file SHALL be served with the content type `text/plain; charset=utf-8`, so that browsers decode the comment as UTF-8.

#### Scenario: Requesting robots.txt

- **WHEN** `/robots.txt` is requested
- **THEN** the response is 200 with the content type `text/plain; charset=utf-8`, the body contains the comment line, and every non-blank line of the body starts with `#`

### Requirement: Bus drawing in the page source

Every page rendered with the shared layout SHALL carry, right after `<!DOCTYPE html>` and before the `html` element, one HTML comment that holds a drawing of a bus with the word `TurnAround` on its side. The comment SHALL contain only printable ASCII characters, spaces and line breaks, so that it lines up in any monospace view of the source, and SHALL NOT contain `--` between its opening and closing marks.

#### Scenario: Home page source

- **WHEN** `/` is requested
- **THEN** the body starts with `<!DOCTYPE html>`, a line break and an HTML comment that closes before `<html`, contains `TurnAround`, holds only printable ASCII characters, spaces and line breaks, and has no `--` between its opening and closing marks

#### Scenario: Route page source

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the body starts with the same doctype and comment as the home page

### Requirement: Rest command in the console

On every full page load of a page rendered with the shared layout, the site's script SHALL write the line 輸入 休息() 試試看 to the browser console once and SHALL define the global function `休息` on `window`. Calling `休息()` SHALL write the line 駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2） to the console. A Turbo visit to another page SHALL NOT write the hint again.

#### Scenario: Hint on a full load

- **WHEN** a browser with JavaScript opens `/`
- **THEN** the console has received 輸入 休息() 試試看 exactly once, and `window.休息` is a function

#### Scenario: Calling the command

- **WHEN** a browser with JavaScript opens `/` and `休息()` is called
- **THEN** the console receives 駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）

#### Scenario: Turbo visit

- **WHEN** a browser with JavaScript opens `/routes/9001` and follows the site name bar's link to `/`
- **THEN** the console has received 輸入 休息() 試試看 exactly once
