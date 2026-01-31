import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="clickable-row"
export default class extends Controller {
	static values = { url: String }

	click(event) {
		// Don't navigate if clicking on interactive elements
		if (event.target.closest("a, button, input, select, textarea, .btn")) {
			return
		}

		Turbo.visit(this.urlValue)
	}
}
