import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["typeInput", "buttonLabel", "valueInput"]

	connect() {
		this.cachedOtherValue = null
		this.userEdited = false
	}

	toggle(event) {
		if (event) event.preventDefault()

		const currentType = this.typeInputTarget.value
		const newType = currentType === "months" ? "fixed" : "months"
		const currentValue = parseFloat(this.valueInputTarget.value) || 0
		const rent = this.rentAmount

		if (!this.userEdited && this.cachedOtherValue !== null) {
			// Round-trip: restore cached value to avoid floating-point drift
			const temp = currentValue
			this.valueInputTarget.value = this.cachedOtherValue
			this.cachedOtherValue = temp
		} else {
			// First toggle or user edited: convert using rent
			this.cachedOtherValue = currentValue
			if (rent > 0 && currentValue > 0) {
				const converted = currentType === "months"
					? currentValue * rent
					: currentValue / rent
				this.valueInputTarget.value = this.roundValue(converted, newType)
			}
		}

		this.typeInputTarget.value = newType
		this.updateLabel(newType)
		this.userEdited = false
	}

	markEdited() {
		this.userEdited = true
	}

	get rentAmount() {
		const rentInput = this.element.closest("form")?.querySelector("[name*='rent_amount']")
		return parseFloat(rentInput?.value) || 0
	}

	updateLabel(type) {
		this.buttonLabelTarget.textContent = type === "months" ? "\u00d7 months" : "\u20b9"
	}

	roundValue(value, type) {
		return type === "months"
			? parseFloat(value.toFixed(2))
			: Math.round(value)
	}
}
