# Lease Manager Features & Requirements

## Overview
A web-based lease management application designed for property managers to handle multiple properties, owners, and tenants with complex lease terms and automated financial workflows.

## Core Entities

### 1. Owners & Properties
- **Owner**: Legal entity owning assets. Attributes: Name, Contact, Invoice Sequence.
- **Property**: The physical asset.
    - **Capacity Management**: Supports partial leasing (e.g., leasing 200 sqft of 1000 sqft).
    - **Availability**: System automatically calculates available capacity based on active leases.

### 2. Tenants & Leases
- **Tenant**: Profile management for lessees.
- **Lease**:
    - **Terms**: Fixed duration (Years/Months).
    - **Auto-Calculation**: End dates derived from start date and duration.
    - **Rent Escalation**: Configurable percentage or fixed amount increases (e.g., 5% every 12 months).
    - **Documents**: Attachment support for contracts.
    - **Renewal**: Workflow to close old lease and start new one with carry-over terms.
    - **Termination**: Early exit handling with automated financial reconciliation.

## Financial Engine

### 1. Invoicing
- **Rent Invoices**: Automated or manual generation.
- **Security Deposits**: Automatically invoiced upon lease creation.
- **Sequencing**: Unique invoice number sequences per Owner.
- **Taxation**: Support for tax configurations on leases.

### 2. Payments & Settlements
- **Payment Tracking**: Record payments via various modes (NEFT, UPI, Cheque, etc.).
- **Payment Status Workflow**: `draft` → `confirmed` → `partially_allocated` / `fully_allocated`. Payments can also be `rejected`.
    - **Draft**: Tenant-submitted payments awaiting confirmation.
    - **Confirmed**: Approved payments eligible for settlement.
    - **Allocated**: Automatically tracked as payments are settled against invoices.
- **Settlement**: "Settleable" interface allows flexible allocation.
    - A single payment can settle multiple invoices.
    - Partial payments and overpayments are handled.
- **Credit Notes**: Generated for security deposit returns or other adjustments.

### 3. Reporting
- **Dashboards**: Visual overview of Revenue and Occupancy.
- **Outstanding Balances**: Track unpaid invoices.

## System Capabilities

### 1. Security & Access
- **Authentication**: Google OAuth and Developer login support.
- **Authorization**: Granular permission scopes (Pundit policies) for Admins, Owners, and Tenants.

### 2. Audit & Integrity
- **Audit Trail**: Complete history of changes (Who, What, When) for critical records.
- **Validations**: Strict data integrity checks (e.g., preventing overlapping leases exceeding capacity).

### 3. User Interface
- **Responsive Design**: Mobile-friendly layouts with drawer-based navigation and CSS Grid.
- **Card & Table Views**: All resource index pages support switchable card and table views with persistent user preference (localStorage).
- **Dark Theme**: DaisyUI v5-powered theming with dark mode support.
- **Filtering & Search**: Advanced filtering (Ransack) and sort sidebars on all index pages.
- **Interactivity**: Hotwire-driven updates for seamless user experience.

## Deployment
- **Kamal**: Configuration available for containerized deployment.
