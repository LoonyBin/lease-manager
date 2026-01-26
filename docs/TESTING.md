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
