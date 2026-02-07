import { Controller } from "@hotwired/stimulus"

// Manages a <details> menu - auto-opens on desktop, closes on link click
export default class extends Controller {
  static values = { autoOpen: Boolean }

  connect() {
    // Only auto-open on desktop (lg breakpoint = 1024px)
    if (this.autoOpenValue && window.innerWidth >= 1024) {
      this.element.setAttribute("open", "")
    }
  }

  close() {
    this.element.removeAttribute("open")
  }
}
