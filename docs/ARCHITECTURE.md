# Architecture

## Technology Stack
- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue
- **Frontend**: HAML, TailwindCSS 4, DaisyUI 5, Hotwire (Turbo + Stimulus)
- **Icons**: heroicons gem
- **Authorization**: Pundit
- **Audit**: PaperTrail
- **Testing**: RSpec, FactoryBot, Capybara
- **Deployment**: Dokku (VM), adhering to 12-factor application principles

## System Design

### 1. Data Model
The application is built around core entities and their financial interactions.

#### Core Entities
- **Owner**: The legal entity owning properties. Maintains an independent invoice sequence. Capable of creating leases directly for owned properties.
- **Property**: A leaseable asset. Supports **Capacity Management** allowing partial leasing (e.g., leasing by area or room count).
- **Tenant**: The lessee.
- **Lease**: The contract connecting Property and Tenant.
  - Manages `start_date`, `duration`, and `end_date`.
  - Manages `payment_due_in` through flexible PostgreSQL `interval` types allowing multiple duration terms.
  - Includes `quantity` (with metrics) and specific `property_schedule` fields.
  - Validates capacity to prevent over-leasing.
  - Handles rent enhancement schedules.

#### Financial Models
- **Invoice**: Generated monthly or for ad-hoc charges (Rent, Security Deposit).
- **CreditNote**: Generated for refunds, deposit returns, or corrections.
- **Payment**: Records incoming funds or refunds. Status workflow: `draft` → `confirmed` → `partially_allocated` / `fully_allocated`, or `rejected`.
- **Entry**: Double-entry ledger mechanism acting as the basis for polymorphic settlements representing financial state for properties and leases.
- **Settlement**: Handled via `SettlementService` coordinating interactions between Payments and Invoices/CreditNotes, managing partial vs full allocations. Readjustment services and Rake tasks ensure financial entry balances are maintained accurately.

#### Polymorphic Settlement Pattern
A `Settleable` interface and `Entry` backing standardizes financial allocations.
- `Payment` can settle multiple `Invoices`.
- `CreditNote` can settle `Invoices` or adjust ledger balances.
- `SettlementService` orchestrates auto-allocation logic.

### 2. Authorization (Pundit)
Access is strictly controlled via Policies.
- **Scope Resolution**: Users only see data relevant to them (e.g., Owners see their properties, Tenants see their leases).
- **Contexts**:
  - `User::Admin`: Full access.
  - `User::Owner`: Access to owned properties and related leases/invoices.
  - `User::Tenant`: Access to personal leases and invoices.
  - `User::Anonymous`: Restricted access (mostly Login/Public pages if any).

### 3. Application Patterns
- **Service Objects**: Complex business logic (e.g., `SecurityDepositInvoicer`, `SettlementService`, backend data sync migrations) is extracted from models/controllers into `app/services`.
- **Form Objects**: Used for complex inputs like Lease Renewal.
- **Concern Extraction**: Shared logic (like `Lease::rent_calculation`) is modularized in concerns.
- **Data Integrations**: Background processing is heavily utilized (via Solid Queue) to offset generation jobs, scaling independently in production.

### 4. UI Architecture
- **Responsive Layout**: CSS Grid-based page structure with a drawer-based navigation sidebar including specialized nested scopes (e.g., Finance).
- **Dashboard**: Modern chart-driven reporting interfaces powered by Chartkick for visually analyzing finances and occupancy.
- **Data Rendering**: Invoice histories transitioned into robust Lease Statements for precise, chronological ledger views.
- **Card & Table Views**: All resource index pages support switchable card and table views. View preference is persisted per-resource in localStorage.
- **Theming**: DaisyUI v5 CSS variables for light and dark theme support.
- **Show Pages**: Consistent styling with page action buttons across all resources.
- **Icons**: Heroicons gem for consistent iconography.

### 5. Audit Trail
`PaperTrail` is enabled for all key models (`Lease`, `Property`, `Tenant`, `Invoice`).
- A `Versions` table stores the history of changes.
- Changes are surfaced in the UI via the "History" sidebar on show pages.
