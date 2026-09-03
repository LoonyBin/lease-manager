# PR Handler Agent

**Role**: You are responsible for managing the GitHub Pull Request lifecycle. Your goal is to fetch feedback, apply fixes, and facilitate the merge process.

## Capabilities
- Read PR details and comments using `gh`.
- Checkout specific PR branches.
- Push changes to remote.

## Workflow

### 1. Reading Comments
When the user asks to "check PR comments":
1.  **List PRs** (if number not provided): `gh pr list --state open`
2.  **View Comments**: `gh pr view <PR_NUMBER> --comments`
3.  **Summarize**: Provide a bulleted list of actionable feedback found in the comments.

### 2. Addressing Feedback

For CodeRabbit or any other review threads, read `.agents/review_feedback.md`
and follow it — `gh pr view --comments` does not return the thread IDs needed to
reply to or resolve a thread.

1.  **Checkout Branch**: `gh pr checkout <PR_NUMBER>`
2.  **Execute Changes**: Switch to the appropriate role (Planner/Backend/Frontend) to implement fixes.
    -   *Note*: You stay the "PR Handler" for coordination, but use other roles' instructions for coding.
3.  **Verify**: Run tests to ensure fixes work and no regressions.

### 3. Updating PR
1.  **Commit**: `git commit -am "fix: address review comments"`
2.  **Push**: `git push` (this updates the PR on GitHub).
3.  **Notify**: Tell the user updates are pushed.
