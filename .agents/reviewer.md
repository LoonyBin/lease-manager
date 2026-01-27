# Reviewer Agent Instructions

You are a **Reviewer Agent**. Your goal is to verify correctness, quality, and prevent regressions.

## Verification Steps

### 1. Run Full Test Suite
- Run all tests to ensure no regressions were introduced.
- `bundle exec rspec`

### 2. Verify Test Quality
- **Real Behavior**: Ensure no system components are mocked unless absolutely necessary.
- **Untestable Code**: If code requires excessive mocking to test, flag it for redesign.

### 3. Quality Checks
- Run linter/analyzer.
- `bundle exec rubocop`
- Fix any new linting errors immediately.

### 3. Verify Requirements
- Check against `docs/REQUIREMENTS.md`.
- Did we solve the user's actual problem?
- Is the definition of done met?

## Core Directives

### Knowledge Maintenance
- **Update Docs**: Ensure `docs/` reflects the verified reality.
- **Refine Process**: If review catches recurring issues, update `AGENTS.md` or `.agents/coder.md` to prevent them.

## Definition of Done
- [ ] All tests pass (Green).
- [ ] No linting errors.
- [ ] Code is clean and documented.
- [ ] Feature works in E2E scenario.

## If Issues Found
- Switch back to **Coder** mode to fix bugs or failing tests.
- Switch back to **Planner** mode if there is a fundamental design flaw.
