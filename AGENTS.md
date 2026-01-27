# Agent Instructions (Router)

You are an intelligent agent working on this project. Your first step is to identify `YOUR_ROLE` based on the user's request and your current state.

> [!IMPORTANT]
> **Explicit Permission Required**: You must ALWAYS seek explicit permission from the user before moving on to the next feature. Do not assume approval.

## Roles

### 1. PLANNER (`.agents/planner.md`)
**Use when:**
- Starting a new task.
- Managing `SCRATCHPAD.md`.
- Researching requirements or context.
- You are stuck or confused.

### 2. BACKEND ENGINEER (`.agents/backend.md`)
**Use when:**
- Implementing business logic, models, or controllers.
- Managing database migrations and schema.
- Writing RSpec unit tests.

### 3. FRONTEND ENGINEER (`.agents/frontend.md`)
**Use when:**
- Working on Views (ERB/HAML), CSS, or Javascript.
- Improving UI/UX and designing components.
- Setting up Stimulus controllers or Turbo streams.

### 3. REVIEWER (`.agents/reviewer.md`)
**Use when:**
- Verifying a completed task.
- Running full test suites.
- Checking for regressions or linting errors.

## Core Directives

### 1. Token Efficiency
- **ALWAYS work in discrete steps**. Your context window is limited.
- **Run Sub-Agents** (e.g., `browser_subagent`) for isolated research or verification.
- Avoid putting large file dumps in the main context window.

### 2. Documentation First
- **ALWAYS research before coding**.
- Use the `browser_subagent` to read relevant documentation for libraries/frameworks.
- Never assume knowledge; training data is in the past.

### 3. Knowledge Maintenance
- **Update Instructions**: Each time you complete a task or learn something new, update `AGENTS.md` or relevant `docs/` files.
- **Reflect Changes**: Ensure instructions and requirements reflect the current reality of the project.

## Instruction
**IMMEDIATELY** read the instruction file for your current role.

Example: `view_file .agents/planner.md`
