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
- **Browsers**: Chrome (Headless/Headed) via Selenium/Cuprite.
- **Fixture Replacement**: FactoryBot
- **Coverage**: SimpleCov (Run `open coverage/index.html` after tests).
- **Security**: Brakeman (Static analysis).
- **Style**: RuboCop.

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

### Manual / Browser Implementation
When manually testing or running browser specs that require login:

**Developer Auth Strategy** (Available in Development/Test):
1. Navigate to `/login` or trigger a login action.
2. Select "Developer" (if prompted) or enter credentials:
   - **Name**: `Admin User`
   - **Email**: `admin` (or any string to identify the user)
   - **Role**: Created dynamically or matched to existing seed data.

*Note: In production/staging, Google OAuth is the primary authentication method.*

## Quality Gates
Before pushing code, ensure the following pass:
1. `bin/rspec` (All tests green)
2. `bin/rubocop` (No style offenses)
3. `bin/brakeman` (No security warnings)
