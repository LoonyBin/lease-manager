# Architecture

## Technology Stack
- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Frontend**: HAML, TailwindCSS 4, DaisyUI 5, Hotwire (Turbo + Stimulus)
- **Icons**: heroicons gem
- **Authorization**: Pundit
- **Audit**: PaperTrail
- **Testing**: RSpec, FactoryBot, Capybara

## System Design

### 1. Data Model
The application is built around core entities and their financial interactions.

#### Core Entities
- **Owner**: The legal entity owning properties. Maintains an independent invoice sequence.
- **Property**: A leaseable asset. Supports **Capacity Management** allowing partial leasing (e.g., leasing by area or room count).
- **Tenant**: The lessee.
- **Lease**: The contract connecting Property and Tenant.
  - Manages `start_date`, `duration`, and `end_date`.
  - Validates capacity to prevent over-leasing.
  - Handles rent enhancement schedules.

#### Financial Models
- **Invoice**: Generated monthly or for ad-hoc charges (Rent, Security Deposit).
- **CreditNote**: Generated for refunds or deposit returns.
- **Payment**: Records incoming funds. Status workflow: `draft` → `confirmed` → `partially_allocated` / `fully_allocated`. Payments can also be `rejected`.
- **Settlement**: Join table managing many-to-many allocations between Payments and Invoices/CreditNotes.

#### Polymorphic Settlement Pattern
A `Settleable` interface standardizes financial allocations.
- `Payment` can settle multiple `Invoices`.
- `CreditNote` can settle `Invoices`.
- `allocate_payment_service` handles the logic of distributing a payment amount across open invoices.

### 2. Authorization (Pundit)
Access is strictly controlled via Policies.
- **Scope Resolution**: Users only see data relevant to them (e.g., Owners see their properties, Tenants see their leases).
- **Contexts**:
  - `User::Admin`: Full access.
  - `User::Owner`: Access to owned properties and related leases/invoices.
  - `User::Tenant`: Access to personal leases and invoices.
  - `User::Anonymous`: Restricted access (mostly Login/Public pages if any).

### 3. Application Patterns
- **Service Objects**: Complex business logic (e.g., `SecurityDepositInvoicer`, `SettleInvoiceService`) is extracted from models/controllers into `app/services`.
- **Form Objects**: Used for complex inputs like Lease Renewal.
- **Concern Extraction**: Shared logic (like `Lease::rent_calculation`) is modularized in concerns.

### 4. UI Architecture
- **Responsive Layout**: CSS Grid-based page structure with a drawer-based navigation sidebar.
- **Card & Table Views**: All resource index pages support switchable card and table views. View preference is persisted per-resource in localStorage.
- **Theming**: DaisyUI v5 CSS variables for light and dark theme support.
- **Show Pages**: Consistent styling with page action buttons across all resources.
- **Icons**: Heroicons gem for consistent iconography.

### 5. Audit Trail
`PaperTrail` is enabled for all key models (`Lease`, `Property`, `Tenant`, `Invoice`).
- A `Versions` table stores the history of changes.
- Changes are surfaced in the UI via the "History" sidebar on show pages.
