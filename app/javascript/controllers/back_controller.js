import { Controller } from "@hotwired/stimulus"

const HISTORY_KEY = "nav_checkpoint_history"

// Connects to data-controller="back"
// Uses the checkpoint stack maintained by history-tracker to navigate back to
// the last natural navigation point, skipping intermediate form pages.
export default class extends Controller {
  go() {
    const currentPath = window.location.pathname
    let stack

    try {
      stack = JSON.parse(sessionStorage.getItem(HISTORY_KEY) || "[]")
    } catch {
      stack = []
    }

    for (let i = stack.length - 1; i >= 0; i--) {
      if (stack[i] !== currentPath) {
        window.location.href = stack[i]
        return
      }
    }

    // Fallback when no checkpoint history is available
    window.history.back()
  }
}
