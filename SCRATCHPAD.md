# Current Goal
- [x] Implement Lease Management (Refactor)
    - [/] Migration: Replace `end_date` with `duration_months`. Add `security_deposit_in_months` (int). Add `terminated_on` (date).
    - [ ] Model: Update associations and validations.
        - `end_date` becomes calculated: `start_date + duration_months` (unless `terminated_on` is set).
        - `security_deposit` amount = `rent_amount * security_deposit_in_months`.
        - **Lease Fields**: `start_date`, `end_date`, `rent_amount`, `security_deposit`, `enhancement_period_months`, `enhancement_rate` (%), `enhancement_flat` ($).
        - **Logic**: End Date snaps to the last day of the month based on duration.
    - [ ] Views: Update Interface.
    - [ ] Specs: Update Request and Model specs.

# Next Goals
- [ ] Implement Invoicing Logic
- [ ] Implement Reconciliation

# Blockers
- None
