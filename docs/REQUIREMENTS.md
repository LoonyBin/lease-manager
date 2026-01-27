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
    - **Renewal**: Flag or process to renew the lease at the end of the term.

### 5. Financials

#### Rent Configuration
- **Base Rent**: The starting monthly rent amount ($r$).
- **Due Date**: On or before the **5th** of each calendar month.
- **Rent Enhancement (Escalation)**:
    - **Frequency**: Every $n$ months.
    - **Alignment**: Enhancements are effective from the **1st of the calendar month**.
    - **Logic**: Rent automatically adjusts based on the enhancement schedule.
    - **Type**:
        - Percentage increase ($i$%)
        - Fixed amount increase ($+\$i$)

#### Security Deposit
- **Initial Lease**: Calculated based on the *initial* rent of the term ($n$ months * Base Rent).
- **Renewal**: Recalculated based on the *new* enhanced rent at the start of the renewal term.

#### Taxes and Charges
- **Types**:
    - Percentage of Rent ($a$%) OR
    - Fixed Amount ($b$)
- **Constraint**: Combination (Percentage + fixed) is **NOT** used.

#### Invoicing
- **Draft Generation**: Automatically generate draft invoices on a configurable date (default: **20th** of the previous month).
- **Invoice Date**: Dated **1st** of the billing month.
- **Numbering**: Sequentially numbered **per Owner**. Each Owner has their own sequence (e.g., OWNER1-001, OWNER2-001).
- **Workflow**:
    1. **Draft**: System generates; Reviewable.
    2. **Finalized**: Confirmed by user. Assigns the official Invoice Number at this stage to ensure no gaps.
    3. **Sent**: Emailed/Sent to tenant.
- **Line Items**: Base Rent, Tax/Charges, Arrears, Credits.

#### Reconciliation
- **Input**: CSV Bank Statement upload.
- **Logic**: Match statement entries against active Lease/Tenant records.
- **Goal**: Identify paid vs unpaid invoices effortlessly.

## Use Cases

1. **Manage Properties**: Add/Edit/List properties.
2. **Manage Tenants**: Add/Edit/List tenants.
3. **Draft Lease**: Create a new lease with:
    - Custom duration.
    - specialized rent enhancement schedule.
    - Tax/Charge configuration.
4. **View Lease Status**: See current rent, next enhancement date, lease expiry.
5. **Renew Lease**: Extend a lease for another term, recalculating deposit.
6. **Invoicing**: Generate monthly drafts, review, finalize.
7. **Reconciliation**: Upload bank CSV, match payments to leases.

## Data & Logic Requirements

### Date Handling & Proration (CRITICAL)
- **Calendar Alignment**:
    - All calculations (Enhancements, Renewals, Expiry) must align to the **1st of the calendar month**.
- **Proration Logic (Discount Model)**:
    - Months are treated as **Full Months**.
    - For partial months (Start/End), a **Prorated Discount** credit is applied to the invoice to reduce the effective amount.
    - *Example*: Join Feb 15th -> Invoice generated for Full Feb Rent, less "Prorated Discount (Feb 1-14)".
- **Duration Calculation**:
    - A "12-month" lease starting Feb 15th will expire **Jan 31st** of the following year.
