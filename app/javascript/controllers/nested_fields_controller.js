import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nested-fields"
export default class extends Controller {
        static targets = ["container", "template"]

        add(event) {
                event.preventDefault()
                const timestamp = new Date().getTime()
                const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)
                this.containerTarget.insertAdjacentHTML("beforeend", content)
        }
}
