import { Controller } from "@hotwired/stimulus"

// Syncs the API-token create form's preset radios with the advanced
// controller×action checkbox matrix. Purely a UX aid: the server resolves the
// submitted preset to its canonical set regardless of what the checkboxes say
// (see ApiTokensController#permissions_for), so nothing here is a security
// boundary. The read-only preset's action list is supplied as a value; "full"
// means every box, "custom" means leave the user's own selection alone.
export default class extends Controller {
        static targets = ["preset", "advanced", "action"]
        static values = { readActions: Array }

        connect() {
                this.applyPreset()
        }

        presetChanged() {
                this.applyPreset()
        }

        // A manual checkbox edit no longer matches a named preset, so reflect
        // that by selecting "custom". Programmatic changes in applyPreset() set
        // .checked directly and fire no event, so they don't re-enter here.
        actionToggled() {
                const custom = this.presetTargets.find((radio) => radio.value === "custom")
                if (custom) custom.checked = true
        }

        applyPreset() {
                const preset = this.selectedPreset
                if (preset === "custom") {
                        if (this.hasAdvancedTarget) this.advancedTarget.open = true
                        return
                }

                const readSet = new Set(this.readActionsValue)
                this.actionTargets.forEach((box) => {
                        box.checked = preset === "full" || readSet.has(box.value)
                })
                if (this.hasAdvancedTarget) this.advancedTarget.open = false
        }

        get selectedPreset() {
                const checked = this.presetTargets.find((radio) => radio.checked)
                return checked ? checked.value : "full"
        }
}
