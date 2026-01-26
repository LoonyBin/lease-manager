# Architecture

## Technology Stack
- **Framework**: Ruby on Rails 8
- **Database**: PostgreSQL
- **Testing**: RSpec
- **Templating**: HAML
- **Styling**: SCSS
- **Linting**: Rubocop (with applicable plugins)

## Application Structure
Standard Rails MVC architecture.

### Key Models (Planned)
- `Property`
- `Tenant`
- `Lease`
- `Invoice`
- `Payment` (for Reconciliation)
- `LineItem`

## Development approach
- **Red-Green-Refactor**: Mandatory for every feature.
- **Coverage**: 100% target (Unit, View, Request, Acceptance).
