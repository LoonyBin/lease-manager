# Lease Manager

A comprehensive property and lease management application built with Ruby on Rails 8. This application handles complex lease scenarios, automated financial workflows, and multi-party resource management.

## Key Features

### 1. Core Management
- **Multi-Owner Support**: Manage properties across multiple legal owners, each with distinct invoice sequencing.
- **Property & Unit Management**: Track properties with capacity management (e.g., partial leasing of areas or rooms).
- **Tenant Management**: Centralized tenant profiles and history.

### 2. Lease Lifecycle
- **Flexible Terms**: Supports fixed-term leases with automatic end date calculations.
- **Partial Leasing**: Validates and tracks capacity usage (e.g., leasing 500sqft of a 1000sqft property).
- **Rent Enhancements**: Automated rent escalation configurations (percentage or fixed amount) over time.
- **Renewals & Terminations**: Guided workflows for extending leases or early termination.

### 3. Financial Engine
- **Automated Invoicing**: Generation of rent invoices with tax calculations.
- **Security Deposits**: Automated invoicing and credit note generation for security deposits upon lease creation and termination.
- **Payment Workflow**: Status-driven lifecycle (draft → confirmed → allocated) with rejection support.
- **Settlements**: Polymorphic payment allocation system. Payments can be split and allocated across multiple invoices or credit notes.
- **Reporting**: Dashboards for Revenue, Outstanding Balances, and Occupancy rates.

### 4. Security & Auditing
- **Role-Based Access Control (RBAC)**: Secure access for Admins, Owners, and Tenants using Pundit policies.
- **Audit Trails**: Full history tracking of all changes (Create, Update, Destroy) for critical resources using PaperTrail.
- **Authentication**: Google OAuth and developer login support.

### 5. User Interface
- **Responsive Design**: Mobile-friendly layouts with drawer-based navigation and CSS Grid.
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
We enforce strict code quality standards using RuboCop.

```bash
# Run linter
bin/rubocop
```

## Documentation

For more detailed information, check the `docs/` directory:
- [Architecture](docs/ARCHITECTURE.md): System design, data models, and patterns.
- [Requirements](docs/REQUIREMENTS.md): Detailed feature specifications.
- [Testing](docs/TESTING.md): Testing strategy and guidelines.
