import { Controller } from "@hotwired/stimulus"

const CYCLE_ALL = ["percentage", "fixed", "inherit"]
const CYCLE_NO_INHERIT = ["percentage", "fixed"]

const LABELS = { percentage: "%", fixed: "₹", inherit: "\u{1F517}" }

export default class extends Controller {
        static targets = ["typeInput", "buttonLabel", "amountInput"]

        connect() {
                this.applyState(this.typeInputTarget.value || "percentage")
        }

        toggle(event) {
                if (event) event.preventDefault()

                const cycle = this.isRenewal ? CYCLE_ALL : CYCLE_NO_INHERIT
                const currentType = this.typeInputTarget.value
                const currentIndex = cycle.indexOf(currentType)
                const nextType = cycle[(currentIndex + 1) % cycle.length]

                this.applyState(nextType)
        }

        applyState(type) {
                this.typeInputTarget.value = type
                this.buttonLabelTarget.textContent = LABELS[type] || type

                if (type === "inherit") {
                        this.amountInputTarget.disabled = true
                        this.amountInputTarget.placeholder = "Inherit"
                } else {
                        this.amountInputTarget.disabled = false
                        this.amountInputTarget.placeholder = ""
                }
        }

        get isRenewal() {
                return !!this.element.dataset.renewedFromId
        }
}
