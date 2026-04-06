import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="back"
export default class extends Controller {
	go() {
		history.back()
	}
}
