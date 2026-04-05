import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "generateButton", "tableBody", "row", "checkbox", "rowStatus", "count", "summary"]

  connect() {
    this.updateGenerateButton()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(cb => { cb.checked = checked })
    this.updateGenerateButton()
  }

  checkboxTargetConnected() {
    this.updateGenerateButton()
  }

  updateGenerateButton() {
    if (!this.hasGenerateButtonTarget) return
    const anyChecked = this.checkboxTargets.some(cb => cb.checked)
    this.generateButtonTarget.disabled = !anyChecked
  }

  async generateDrafts() {
    const selectedRows = this.rowTargets.filter((row, i) => this.checkboxTargets[i]?.checked)
    if (selectedRows.length === 0) return

    // Disable all inputs during generation
    this.checkboxTargets.forEach(cb => { cb.disabled = true })
    this.generateButtonTarget.disabled = true
    if (this.hasSelectAllTarget) this.selectAllTarget.disabled = true

    const queue = [...selectedRows]
    let successCount = 0
    let failCount = 0
    const concurrency = 3
    let inFlight = 0

    await new Promise((resolve) => {
      const dispatch = () => {
        while (inFlight < concurrency && queue.length > 0) {
          const row = queue.shift()
          inFlight++
          this.processRow(row)
            .then(ok => { ok ? successCount++ : failCount++ })
            .finally(() => {
              inFlight--
              if (queue.length > 0) {
                dispatch()
              } else if (inFlight === 0) {
                resolve()
              }
            })
        }
        if (queue.length === 0 && inFlight === 0) resolve()
      }
      dispatch()
    })

    this.showSummary(successCount, failCount)

    // Re-enable failed rows' checkboxes
    this.rowTargets.forEach((row, i) => {
      const statusEl = row.querySelector("[data-audit-target='rowStatus']")
      if (statusEl && statusEl.dataset.state === "error") {
        if (this.checkboxTargets[i]) this.checkboxTargets[i].disabled = false
      }
    })

    const anyFailed = failCount > 0
    if (this.hasGenerateButtonTarget) {
      this.generateButtonTarget.disabled = !anyFailed
    }
    if (this.hasSelectAllTarget) this.selectAllTarget.disabled = false
  }

  async processRow(row) {
    const statusEl = row.querySelector("[data-audit-target='rowStatus']")
    const leaseId = row.dataset.leaseId
    const date = row.dataset.date

    this.setRowStatus(statusEl, "loading")

    try {
      const response = await fetch("/invoices.json", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          invoice: {
            lease_id: leaseId,
            date: date,
            status: "draft",
            document_type: "invoice"
          }
        })
      })

      if (response.ok) {
        this.setRowStatus(statusEl, "success", response.headers.get("Location"))
        row.classList.add("opacity-60")
        return true
      } else {
        const data = await response.json()
        const message = Object.values(data).flat().join(", ") || "Unknown error"
        this.setRowStatus(statusEl, "error", null, message)
        return false
      }
    } catch (err) {
      this.setRowStatus(statusEl, "error", null, err.message || "Network error")
      return false
    }
  }

  setRowStatus(el, state, url = null, message = null) {
    if (!el) return
    el.dataset.state = state

    if (state === "loading") {
      el.innerHTML = '<span class="loading loading-spinner loading-xs text-info"></span>'
    } else if (state === "success") {
      const link = url
        ? `<a href="${url}" class="link link-success text-sm font-medium">&#10003; Created</a>`
        : '<span class="text-success text-sm font-medium">&#10003; Created</span>'
      el.innerHTML = link
    } else if (state === "error") {
      el.innerHTML = `<span class="text-error text-sm font-medium" title="${this.escapeHtml(message || '')}">&#10007; Failed</span>`
    }
  }

  showSummary(successCount, failCount) {
    if (!this.hasSummaryTarget) return

    const total = successCount + failCount
    let html = `<div class="alert ${failCount > 0 ? (successCount > 0 ? "alert-warning" : "alert-error") : "alert-success"} shadow-lg mt-2">`
    html += `<span>${successCount} generated, ${failCount} failed out of ${total} selected.</span>`

    if (failCount === 0) {
      html += ` <a href="/invoices?q[status_eq]=draft" class="btn btn-sm btn-ghost">View Drafts &rarr;</a>`
    }

    html += `</div>`
    this.summaryTarget.innerHTML = html
    this.summaryTarget.classList.remove("hidden")
  }

  escapeHtml(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
