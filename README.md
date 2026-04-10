# Lease Manager

A comprehensive property and lease management application built with Ruby on Rails 8. This application handles complex lease scenarios, automated financial workflows, and multi-party resource management.

## Key Features

### 1. Core Management
- **Multi-Owner Support**: Manage properties across multiple legal owners, each with distinct invoice sequencing.
- **Property & Unit Management**: Track properties with capacity management (e.g., partial leasing of areas or rooms) and define layout and schedules.
- **Tenant Management**: Centralized tenant profiles and history.

### 2. Lease Lifecycle
- **Flexible Terms**: Supports calendar-aware payment terms allowing complex dynamic duration configurations. Includes fixed-term leases with automatic end date calculations.
- **Partial Leasing**: Validates and tracks capacity usage (e.g., leasing 500sqft of a 1000sqft property) and quantity details (with units).
- **Property Schedules**: Dedicated tracking of schedules directly linked to the lease.
- **Rent Enhancements**: Automated rent escalation configurations (percentage or fixed amount) over time.
- **Renewals & Terminations**: Guided workflows for extending leases, carrying over schedules, or ending early.
- **Filtering**: Filter leases by dynamic statuses.

### 3. Financial Engine
- **Automated Invoicing**: Generation of rent invoices with tax calculations.
- **Security Deposits**: Automated invoicing and credit note generation for security deposits (supports both months-based decimals and fixed amounts) upon lease creation and termination.
- **Lease Statement**: Provides a consolidated chronological ledger of invoices, payments, and credit notes for a specific lease.
- **Payment Workflow**: Status-driven lifecycle (`draft` → `confirmed` → `partially_allocated` / `fully_allocated`) with `rejected` support. Covers both payments and refunds.
- **Settlements**: Polymorphic payment allocation system backed by double-entry ledger records (`Entry`). Payments can be split and allocated across multiple invoices or credit notes automatically.
- **Reporting**: Dashboards featuring interactive graphic charts for Revenue, Occupancy rates, and aggregated Cached Outstanding Balances.

### 4. Security & Auditing
- **Role-Based Access Control (RBAC)**: Secure access for Admins, Owners (who seamlessly create leases for their properties), and Tenants using Pundit policies.
- **Audit Trails**: Full history tracking of all changes (Create, Update, Destroy) for critical resources using PaperTrail.
- **Authentication**: Modern OAuth integration via Google (credentials managed securely via Rails credentials) alongside developer login support.

### 5. Backend & Deployment
- **Background Jobs**: Integrated with Rails 8 Solid Queue for reliable, database-backed job orchestration.
- **Deployment Strategy**: Deployed to Dokku on a VM. The application follows 12-factor principles, isolating architecture from the specific deployment target.

### 6. User Interface
- **Responsive Design**: Mobile-friendly layouts with drawer-based navigation and CSS Grid.
- **Navigation**: Dedicated Finance accordion menu housing Invoices and Payments sub-items.
- **Card & Table Views**: Switchable card and table views on all resource index pages with persistent user preference.
- **Dark Theme**: DaisyUI v5-powered theming with dark mode support.
- **Filtering & Sorting**: Advanced filtering (Ransack) and sort sidebars on all index pages.

## Technology Stack

- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Frontend**:
  - TailwindCSS 4 (Styling)
  - DaisyUI 5 (Component Library with dark theme)
  - Hotwire (Turbo & Stimulus for reactivity)
  - HAML (Templating)
- **Key Gems**:
  - `pundit`: Authorization
  - `paper_trail`: Audit logging
  - `solid_queue`: Background jobs
  - `heroicons`: Icon library
  - `kaminari`: Pagination
  - `ransack`: Filtering and Sorting
  - `chartkick` / `groupdate`: Visualization

## Getting Started

### Prerequisites
- Check `.ruby-version` for the required Ruby version.
- PostgreSQL installed and running.

### Setup
Run the setup script to install dependencies and prepare the database:

```bash
bin/setup
```

### Running the Server
Start the development server (Rails + Tailwind watcher):

```bash
bin/dev
```

Visit `http://localhost:3000` in your browser.

## Development

### Login
For local development, you can use the default Admin account:
- **Email**: `admin`
- **Role**: Admin

(Note: Authentication uses a developer strategy in non-production environments).

### Testing
This project uses RSpec for testing.

```bash
# Run all tests
bin/rspec

# Run specific file
bin/rspec spec/models/lease_spec.rb
```

### Code Quality
We enforce strict code quality standards using RuboCop and fast suites, automated via `.githooks` for `pre-commit` and `pre-push` triggers.

```bash
# Run linter
bin/rubocop
```

## Documentation

For more detailed information, check the `docs/` directory:
- [Architecture](docs/ARCHITECTURE.md): System design, data models, and patterns.
- [Requirements](docs/REQUIREMENTS.md): Detailed feature specifications.
- [Testing](docs/TESTING.md): Testing strategy and guidelines.
