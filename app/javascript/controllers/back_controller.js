import { Controller } from "@hotwired/stimulus"

const HISTORY_KEY = "nav_checkpoint_history"

// Connects to data-controller="back"
// Uses the checkpoint stack maintained by history-tracker to navigate back to
// the last natural navigation point, skipping intermediate form pages.
export default class extends Controller {
  go() {
    const currentPath = window.location.pathname + window.location.search
    let stack

    try {
      const parsed = JSON.parse(sessionStorage.getItem(HISTORY_KEY) || "[]")
      stack = Array.isArray(parsed) ? parsed : []
    } catch {
      stack = []
    }

    for (let i = stack.length - 1; i >= 0; i--) {
      if (stack[i] !== currentPath) {
        const target = stack[i]
        // Drop the consumed checkpoint and everything newer, or the tracker
        // re-appends the destination and the next click navigates forward.
        sessionStorage.setItem(HISTORY_KEY, JSON.stringify(stack.slice(0, i)))
        window.location.href = target
        return
      }
    }

    // Fallback when no checkpoint history is available
    window.history.back()
  }
}
