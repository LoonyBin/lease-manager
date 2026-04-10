# Lease Manager Features & Requirements

## Overview
A web-based lease management application designed for property managers to handle multiple properties, owners, and tenants with complex lease terms and automated financial workflows. It features modern reporting and robust Google Cloud Run deployments.

## Core Entities

### 1. Owners & Properties
- **Owner**: Legal entity owning assets. Attributes: Name, Contact, Invoice Sequence. Owners can independently define leases for their properties.
- **Property**: The physical asset.
    - **Capacity Management**: Supports partial leasing (e.g., leasing 200 sqft of 1000 sqft or specifying unit multiples).
    - **Property Schedule**: Defines boundaries, layouts, or availability schedules.
    - **Availability**: System automatically calculates available capacity based on active leases.

### 2. Tenants & Leases
- **Tenant**: Profile management for lessees.
- **Lease**:
    - **Terms**: Flexible duration tracking and calendar-aware payment terms that handle complex configurations (e.g., specifying multi-unit terms like "1 year 15 days").
    - **Auto-Calculation**: End dates derived from start date and duration.
    - **Rent Escalation**: Configurable percentage or fixed amount increases (e.g., 5% every 12 months).
    - **Documents**: Attachment support for contracts.
    - **Renewal**: Workflow to close old lease and start new one with carry-over schedules and capacities.
    - **Termination**: Early exit handling with automated financial reconciliation.

## Financial Engine

### 1. Invoicing & Credit
- **Rent Invoices**: Automated or manual generation. Total amounts actively factor tax configurations.
- **Security Deposits**: Automatically invoiced upon lease creation. Supports decimal values for months or fixed flat-amount inputs.
- **Credit Notes & Refunds**: Tracked equivalently to invoices for returning limits, reversing incorrect charges, or processing deposit returns.
- **Sequencing**: Unique invoice number sequences per Owner.

### 2. Payments & Settlements
- **Payment Tracking**: Record payments/refunds via various modes (NEFT, UPI, Cheque, etc.).
- **Payment Status Workflow**: `draft` → `confirmed` → `partially_allocated` / `fully_allocated`, handling automatic status progressions via ledger. Can also be `rejected`.
    - **Draft**: Tenant-submitted payments awaiting confirmation.
    - **Confirmed**: Approved payments eligible for settlement.
    - **Allocated**: Automatically tracked via `Entry` ledgers as payments are settled.
- **Settlement**: "Settleable" interface and underlying `Entry` balances handle allocations.
    - A single payment can settle multiple invoices.
    - Partial payments, overpayments, and balance adjustments are handled effortlessly via rake tasks/automation.

### 3. Reporting
- **Dashboards**: Visual, graphic-chart overview of Revenue and Occupancy figures.
- **Outstanding Balances**: Track unpaid invoices. Fast reporting caches totals on the Owner and Lease indexes for high-performance viewing.
- **Lease Statements**: Comprehensive, sequential chronology replacing regular invoice lists to show running ledger balances.

## System Capabilities

### 1. Security & Access
- **Authentication**: Enterprise Google OAuth integrations (keys encrypted in Rails credentials) and Developer login support.
- **Authorization**: Granular permission scopes (Pundit policies) for Admins, Owners, and Tenants.

### 2. Audit & Integrity
- **Audit Trail**: Complete history of changes (Who, What, When) for critical records.
- **Validations**: Strict data integrity checks (e.g., preventing overlapping leases exceeding capacity).
- **Background Processing**: Heavy ops queued securely by Solid Queue.

### 3. User Interface
- **Responsive Design**: Mobile-friendly layouts with drawer-based navigation and nested menu items.
- **Card & Table Views**: All resource index pages support switchable card and table views with persistent user preference (localStorage).
- **Dark Theme**: DaisyUI v5-powered theming with dark mode support.
- **Filtering & Search**: Advanced filtering (Ransack), status-based filters for leases, and sort sidebars on all index pages.
- **Interactivity**: Hotwire-driven updates for seamless user experience without full page reloads.

## Deployment
- **Platform**: Deployed via Dokku on a VM, adhering to 12-factor application architecture.
- **Networking**: Proxied by Cloudflare Workers managing custom domain constraints seamlessly.
