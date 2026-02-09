import { Controller } from "@hotwired/stimulus"

// Manages a <details> menu - auto-opens on desktop if child nav matches body class
export default class extends Controller {
  connect() {
    // Only auto-open on desktop (lg breakpoint = 1024px)
    if (this.shouldAutoOpen && window.innerWidth >= 1024) {
      this.element.setAttribute("open", "")
    }
  }

  close() {
    this.element.removeAttribute("open")
  }

  get shouldAutoOpen() {
    // Check if any child nav item matches current controller (body class)
    const navItems = this.element.querySelectorAll("[data-nav]")
    const bodyClasses = document.body.className.split(" ")
    return Array.from(navItems).some(item =>
      bodyClasses.includes(item.dataset.nav)
    )
  }
}
