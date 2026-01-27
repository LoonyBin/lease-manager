import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
        static targets = ["typeInput", "buttonLabel"]

        toggle(event) {
                if (event) event.preventDefault()

                const currentType = this.typeInputTarget.value
                const newType = currentType === "percentage" ? "fixed" : "percentage"

                this.typeInputTarget.value = newType
                this.updateLabel(newType)
        }

        updateLabel(type) {
                this.buttonLabelTarget.textContent = type === "percentage" ? "%" : "₹"
        }
}
