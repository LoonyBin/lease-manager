# Lease Manager Requirements

## Overview
A lease management application for property managers handling multiple properties, tenants, and complex lease terms.

## Core Entities

### 1. Owner
- **Description**: The legal entity that owns the property.
- **Attributes**:
    - Name
    - Address
    - Contact Details
    - **Invoice Sequence**: Maintains a counter for invoices issued by this owner.

### 2. Property
- **Description**: A physical unit being rented out.
- **Attributes**:
    - **Owner**: Link to Owner.
    - Name/Identifier (e.g., "Apt 4B", "123 Main St")
    - Address
    - (Potential) Type (Residential, Commercial, etc.) - TBD

### 3. Tenant
- **Description**: The entity renting the property.
- **Attributes**:
    - Name
    - Contact Information
    - Identity details (TBD)

### 4. Lease
- **Description**: The legal agreement between Property and Tenant.
- **Attributes**:
    - **Property**: Link to Property
    - **Tenant**: Link to Tenant
    - **Start Date**: Date lease begins.
    - **Duration**: Fixed term defined in Years + Months (e.g., 1 Year 6 Months).
    - **End Date**: Calculated from Start Date + Duration.
    - **Terminated On**: Optional date if lease is ended early (not visible during creation).
    - **Documents**: Capability to upload and store multiple attachments (contracts, ID proofs).

### 5. Payment
- **Description**: A record of money received from a Tenant.
- **Attributes**:
    - **Lease**: Link to Lease.
    - **Amount**: Value of the payment.
    - **Date**: Date received.
    - **Mode**: Method of payment (RTGS, NEFT, IMPS, UPI, Cheque, Cash, Demand Draft, Tax Deducted at Source).
    - **Reference Number**: Transaction ID or Check Number.

## Financials

### Rent Configuration
- **Base Rent**: The starting monthly rent amount ($r$).
- **Due Date**: On or before the **5th** of each calendar month.
- **Rent Enhancement (Escalation)**:
    - **Frequency**: Every $n$ months.
    - **Alignment**: Enhancements are effective from the **1st of the calendar month**.
    - **Logic**: Rent automatically adjusts based on the enhancement schedule.
    - **Type** (Mutually Exclusive):
        1.  **Percentage**: Increase by $i$%.
        2.  **Fixed Amount**: Increase by $+\$i$.
    - **Constraint**: Must choose exactly one type; cannot use both.

### Security Deposit
- **Initial Lease**: Calculated based on the *initial* rent of the term ($n$ months * Base Rent).
- **Renewal**: Recalculated based on the *new* enhanced rent at the start of the renewal term.

### Taxes and Charges
- **Configuration**: Applicable taxes (e.g., GST @ 18%) defined on the Lease.
- **Invoicing**: Taxes must be calculated explicitly and shown on the Invoice.

### Invoicing
- **Draft Generation**: Automatically generate draft invoices on a configurable date (default: **20th** of the previous month).
- **Invoice Date**: Dated **1st** of the billing month.
- **Numbering**: Sequentially numbered **per Owner**. Each Owner has their own sequence (e.g., OWNER1-001, OWNER2-001).
- **Workflow**:
    1. **Draft**: System generates; or User manually generates missing months via "Generate" button.
    2. **Finalized**: Confirmed by user. Assigns the official Invoice Number.
    3. **Sent**: Emailed/Sent to tenant.
    4. **Paid/Partially Paid**: Updated automatically when Payments are allocated.
- **Visibility**: All invoices listed directly on the Lease show page, with visual indicators for "missing" months (gaps).

### Reconciliation (Planned)
- **Input**: CSV Bank Statement upload.
- **Logic**: Match statement entries against active Lease/Tenant records.
- **Goal**: Identify paid vs unpaid invoices effortlessly.

## Lease Lifecycle Logic

### Termination
- **Process**: Manual action via a dedicated UI (Modal).
- **Input**: User selects `terminated_on` date.
- **Validation**: Date must be within the active lease duration.

### Renewal
- **Process**: One-click "Renew" action on an existing lease.
- **Logic**:
    1.  **Terminate Old**: Ends current lease at its natural end date (or specified date).
    2.  **Create New**: Creates a fresh Lease record.
    3.  **Data Copy**: Copies Tenant, Property, and Configuration from the old lease.
    4.  **Rent Calculation**: Automatically sets new Base Rent = (Old Final Rent + Enhancement Terms).

## Data & Logic Requirements

### Date Handling & Proration (CRITICAL)
- **Calendar Alignment**: All calculations (Enhancements, Renewals, Expiry) must align to the **1st of the calendar month**.
- **Proration Logic (Discount Model)**:
    - Months are treated as **Full Months**.
    - For partial months (Start/End), a **Prorated Discount** credit is applied to the invoice.
- **Duration Calculation**:
    - A "12-month" lease starting Feb 15th will expire **Jan 31st** of the following year.

## Future Requirements / Backlog
- **Security Deposit Invoicing**: Ability to generate invoices and credit notes for security deposit items on lease creation, renewal, and termination.
- **Authentication**: Implementation of Google OIDC or OAuth for user login.
- **Mobile Support**: Dedicated mobile interface or responsive design optimization for mobile users.
- **Hosting**: Identification and setup of production hosting environment.
- **Partial Leasing**: Ability to lease a part of the property. (Ex: 18000 sft of 100000 sft, 100 rooms out of 250 rooms).
