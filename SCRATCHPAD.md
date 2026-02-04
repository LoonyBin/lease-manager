# Rules
- **Explicit Permission Required**: You must ALWAYS seek explicit permission from the user before moving on to the next feature. Do not assume approval.

# History
- [x] Migrate to Tailwind CSS & Simple Form
- [x] Setup Developer Tools (Foreman, Guard)
- [x] i18n & Locales (Rupee, Lease Model updates)
- [x] Implement Owner Model
- [x] Implement Invoicing Logic
- [x] Implement Owners Interface
- [x] Implement Payments Support

# Current Goal
- [x] Ability to generate invoices and credit notes for security deposit on lease creation, renewal, and termination
- [x] Review Navigation Bar Order


    - [x] Add `tax_name` and `tax_rate` to Lease
    - [x] Update InvoiceGenerator to create tax LineItems
    - [x] Display taxes on Invoice views
- [x] Invoice Workflow Improvements
    - [x] Invoices table on Lease show page
    - [x] Missing months identified
    - [x] Generate button creates invoices
- [x] Invoice Proration Discounts
    - [x] Calculate unused days for first/last months
    - [x] Create discount line items
    - [x] Tax on net rent (rent - discount)
- [x] Lease Lifecycle
    - [x] Termination modal with date picker
    - [x] Renewal with LeaseRenewalService

# Next Goals
- [ ] Lease Documents (ActiveStorage)
- [ ] Lease Taxes
- [ ] Invoice Workflow Improvements
- [ ] Lease Lifecycle
- [ ] Lease Documents
- [ ] Reconciliation
- [x] Reports

# Future TODO
- [ ] Ability to generate invoices and credit notes for security deposit on lease creation, renewal, and termination
- [ ] Google OIDC or OAuth
- [ ] Mobile interface
- [ ] Finding and setting up hosting for production

# Blockers
- None
