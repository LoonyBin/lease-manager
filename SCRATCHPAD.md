# Current Goal
- [x] Migrate to Tailwind CSS and Simple Form
    - [x] Add gems (`tailwindcss-rails`, `simple_form`)
    - [x] Install Tailwind and Simple Form
    - [x] Configure Simple Form wrappers for Tailwind
- [x] Migrate to Tailwind CSS and Simple Form
    - [x] Add gems (`tailwindcss-rails`, `simple_form`)
    - [x] Install Tailwind and Simple Form
    - [x] Configure Simple Form wrappers for Tailwind
    - [x] Refactor Layout (`application.html.erb` -> `haml` + Tailwind)
    - [x] Refactor Views (Properties, Tenants, Leases)
    - [x] Migrate to daisyUI (npm install, plugin config, view refactoring)
- [x] Setup Developer Tools (Foreman & Guard)
    - [x] Verify Foreman (`bin/dev`, `Procfile.dev`)
    - [x] Add Guard gems (`guard`, `guard-rspec`)
    - [x] Configure Guardfile
- [/] Setup Guard for RuboCop
    - [ ] Add `guard-rubocop` gem
    - [ ] Initialize `Guardfile` for RuboCop
    - [ ] Configure auto-correct ('--autocorrect')
- [x] i18n & Locales
    - [x] Change currency to Rupee (INR)
    - [x] Fix RuboCop locale errors
    - [x] Verify currency formatting in views
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
