import { Controller } from "@hotwired/stimulus"

// Persists view toggle preference (card/table) per resource type in localStorage
// Resource type is read from body class (controller name)
export default class extends Controller {
  connect() {
    this.restorePreference()
    this.element.addEventListener("change", this.savePreference.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("change", this.savePreference.bind(this))
  }

  restorePreference() {
    const saved = localStorage.getItem(this.storageKey)
    if (saved !== null) {
      this.element.checked = saved === "table"
    }
  }

  savePreference() {
    const value = this.element.checked ? "table" : "card"
    localStorage.setItem(this.storageKey, value)
  }

  get storageKey() {
    return `view_preference_${this.resourceName}`
  }

  get resourceName() {
    // Read controller name from body class (first class that's a resource)
    const bodyClasses = document.body.className.split(" ")
    return bodyClasses[0] || "default"
  }
}
