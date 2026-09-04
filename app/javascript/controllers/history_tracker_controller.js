import { Controller } from "@hotwired/stimulus"

const HISTORY_KEY = "nav_checkpoint_history"
const NON_CHECKPOINT_PATTERNS = [/\/new(\?.*)?$/, /\/edit(\?.*)?$/]

// Connects to data-controller="history-tracker"
// Mount on the <body> in the application layout so every page visit is recorded.
// Only "checkpoint" pages (index/show – not forms) are pushed onto the stack so
// the back controller can skip straight past any intermediate form pages.
export default class extends Controller {
  connect() {
    const path = window.location.pathname
    if (NON_CHECKPOINT_PATTERNS.some(re => re.test(path))) return

    const checkpoint = path + window.location.search
    const stack = this.#load()
    if (stack[stack.length - 1] !== checkpoint) {
      stack.push(checkpoint)
      this.#save(stack)
    }
  }

  #load() {
    try {
      const parsed = JSON.parse(sessionStorage.getItem(HISTORY_KEY) || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch {
      return []
    }
  }

  #save(stack) {
    sessionStorage.setItem(HISTORY_KEY, JSON.stringify(stack.slice(-50)))
  }
}
