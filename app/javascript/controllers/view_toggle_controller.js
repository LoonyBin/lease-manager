import { Controller } from "@hotwired/stimulus"

// Persists view toggle preference (card/table) per resource type in localStorage
export default class extends Controller {
  static values = {
    resource: String,
    default: { type: String, default: "card" }
  }

  connect() {
    this.restorePreference()
    this.element.addEventListener("change", this.savePreference.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("change", this.savePreference.bind(this))
  }

  restorePreference() {
    const saved = localStorage.getItem(this.storageKey)
    const preference = saved !== null ? saved : this.defaultValue
    this.element.checked = preference === "table"
  }

  savePreference() {
    const value = this.element.checked ? "table" : "card"
    localStorage.setItem(this.storageKey, value)
  }

  get storageKey() {
    return `view_preference_${this.resourceValue}`
  }
}
