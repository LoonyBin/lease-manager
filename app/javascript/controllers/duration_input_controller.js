import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "unit"]

  update() {
    let years = 0, months = 0, days = 0, hours = 0, minutes = 0, seconds = 0;
    
    this.unitTargets.forEach(target => {
      const val = parseInt(target.value, 10) || 0;
      switch(target.dataset.unit) {
        case "years": years = val; break;
        case "months": months = val; break;
        case "days": days = val; break;
        case "hours": hours = val; break;
        case "minutes": minutes = val; break;
        case "seconds": seconds = val; break;
      }
    });

    let datePart = "P";
    if (years > 0) datePart += `${years}Y`;
    if (months > 0) datePart += `${months}M`;
    if (days > 0) datePart += `${days}D`;
    
    // Fallback if all date components are zero and no time components exist
    if (datePart === "P" && hours === 0 && minutes === 0 && seconds === 0) {
      datePart = "P0D";
    }

    let timePart = "";
    if (hours > 0 || minutes > 0 || seconds > 0) {
      timePart = "T";
      if (hours > 0) timePart += `${hours}H`;
      if (minutes > 0) timePart += `${minutes}M`;
      if (seconds > 0) timePart += `${seconds}S`;
    }

    this.hiddenTarget.value = datePart + timePart;
  }
}
