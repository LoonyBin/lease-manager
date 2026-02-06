# Testing Strategy

## Core Principles
1. **Red-Green-Refactor**: All code must be driven by tests.
    - Write a failing test first.
    - Write minimal code to pass.
    - Refactor.
2. **Full Coverage**: Test all layers.
    - **Unit Tests**: Models, Services.
    - **View Tests**: HAML rendering.
    - **Request Tests**: Controllers/API endpoints.
    - **Acceptance/System Tests**: End-to-End user flows.

## Tools
- **Framework**: RSpec
- **Factories**: FactoryBot (StandardRails convention)
- **Coverage**: SimpleCov (to verify coverage)

## Commit Policy
- Each feature must be a separate commit.
- Commits must follow the Red-Green-Refactor cycle.

## Manual Testing / Browser Automation

### Login Instructions
If you need to log in during manual testing or browser automation:
1. Navigate to `/auth/developer` (or trigger it via Sign In).
2. **Name**: `Admin User`
3. **Email**: `admin` (Use "admin" as the unique identifier)
If you need to test as a different user, use the `User` model and use that user's uid as the email.


### Tab Management
Close the browser tab at the end of the session.
