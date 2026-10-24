// The console's 休息() for visitors who open the browser's developer tools: a
// hint on how to call it, and the rest rule for bus drivers that it writes,
// the one the layover metrics are measured against.

// Written when the command is installed, once a full load.
const HINT = "輸入 休息() 試試看"
// Written by 休息(). Article 19-2 of 汽車運輸業管理規則 is about driving, so
// the rule names the driver, not "work" as the comment in robots.txt does.
const RULE = "駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）"

// Defines window.休息, which writes the rule and returns undefined, then
// writes the hint.
export function installRestCommand() {
  window.休息 = () => {
    console.log(RULE)
  }
  console.log(HINT)
}
