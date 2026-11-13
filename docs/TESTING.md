# Testing Strategy

## Core Principles
1. **Red-Green-Refactor**: ALL code changes must be driven by tests.
2. **Behavior Driven**: Use RSpec `describe` and `context` blocks to document behavior clearly.
3. **Full Stack Coverage**:
    - **Models**: Validations, Scopes, Business Logic.
    - **Requests**: Controller authorization and response formats.
    - **System/Integration**: End-to-end flows (using Capybara).
    - **Policies**: Pundit permission checks.

## Tooling
- **Framework**: RSpec
- **Browsers**: Headless Chrome via Cuprite (`spec/system`, test group only). Chrome must be installed; a missing browser fails the specs rather than skipping them. Build Tailwind first (`bin/rails tailwindcss:build`).
- **Fixture Replacement**: FactoryBot
- **Coverage**: SimpleCov (Run `open coverage/index.html` after tests).
- **Security**: Brakeman (Static analysis).
- **Style**: RuboCop.
- **Automation**: Git hooks ensure quality limits on commits/pushes.

## Running Tests

### Automated Suite
```bash
# Run all specs
bin/rspec

# Run specific type
bin/rspec spec/models
bin/rspec spec/system

# Guard (Watch mode)
bundle exec guard
```

### Git Hooks Enforcements
The project enforces pre-commit and pre-push Git Hook requirements that guarantee quality before CI execution:
- **`pre-commit`**: Executes RuboCop styling assessments and essential checks.
- **`pre-push`**: Ensures the full comprehensive RSpec suite resolves without conflicts.
Local `.githooks` paths must be registered for enforcement checking (`git config core.hooksPath .githooks`).

### Manual / Browser Implementation
When manually testing or running browser specs that require login:

**Developer Auth Strategy** (Available in Development/Test):
1. Navigate to `/login` or trigger a login action.
2. Select "Developer" (if prompted) or enter credentials:
   - **Name**: `Admin User`
   - **Email**: `admin` (or any string to identify the user)
   - **Role**: Created dynamically or matched to existing seed data.

*Note: In production/staging, Google OAuth securely manages authentication via Rails Secrets.*

## Quality Gates
Before pushing code, ensure the following pass locally:
1. `bin/rspec` (All tests green)
2. `bin/rubocop` (No style offenses)
3. `bin/brakeman` (No security warnings)

The other CI security scans and how to run them locally are in [Security tooling and review](SECURITY.md).

During continuous integration runs, jobs automatically gate deployment success metrics prior to dispatching upgrades, preventing stale iterations.

## Financial search integration checks

`spec/requests/financial_search_spec.rb` submits the invoice/payment pages'
rendered amount-filter and sort controls and checks actual result IDs. It also
checks that matching records belonging to another tenant stay outside session
and granted-token search results. Draft records and zero-deposit leases avoid
settlement and notification side effects.

```bash
bundle exec rspec spec/requests/financial_search_spec.rb spec/requests/ransack_search_spec.rb spec/requests/api_token_permissions_spec.rb
```

Existing authentication, token-gate and policy specs cover credential rejection,
action grants and role rules. The new examples cover controller/query integration;
they do not test generic parser rules or reproduce upstream security findings.
