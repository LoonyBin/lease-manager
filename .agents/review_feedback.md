---
name: address-coderabbit-review
description: Process CodeRabbit (and other bot or human) review comments on a GitHub PR — verify each finding against current code, then either fix and push, or reply with a justification. Resolves review threads via the GitHub GraphQL API. Use when asked to address CodeRabbit feedback, triage bot comments, sweep open PRs for review feedback, or resolve PR review threads.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Review-feedback handler

Sub-role of **PR Handler** (`.agents/pr_handler.md`). The frontmatter above is
Claude Code skill metadata, so this file can also be dropped into
`.claude/skills/address-coderabbit-review/SKILL.md` unchanged.

Triages review comments on a GitHub PR. For each comment you verify the finding
against the current code, then either **fix it** (commit + push + resolve) or
**decline it** (reply with a reason + resolve).

Written for CodeRabbit, but the workflow applies to any reviewer. Human comments
get the same treatment minus the "check the bot isn't hallucinating" step — and
a human's thread is never resolved without a reply.

## When to use

- Asked to "address CodeRabbit", "process the bot review", "go through PR review
  comments", or given a PR with pending review threads.
- On a periodic sweep of open PRs (see **Sweep mode**).

## Required inputs

- **PR number or URL.** In sweep mode, discover them instead.
- **The PR branch checked out locally**, if you intend to push fixes.

Derive `OWNER`/`REPO` from `gh repo view --json nameWithOwner -q .nameWithOwner`.

## Sweep mode

When the task is "scan open PRs for review feedback" rather than one named PR:

```bash
gh pr list --repo "$OWNER/$REPO" --state open \
  --json number,title,author,isDraft,headRefName
```

For each PR, count unresolved bot threads with the Step 2 query and skip the
ones at zero. Dependabot PRs are owned by the Dependency Steward routine — check
who owns a PR before touching it.

## Workflow

1. Confirm the PR, the branch is checked out, the working tree is clean.
2. Fetch all review threads (inline + conversation) with their IDs.
3. Read each finding, including its "Prompt for AI Agents" block.
4. **Verify the finding against current code.**
5. Decide FIX / DECLINE / DEFER and record the reason.
6. FIX → edit, lint, commit, push. DECLINE/DEFER → reply with the reason.
7. Resolve the thread.
8. Re-check for reviewer replies that push back.
9. Summarise: fixed / declined / deferred / still open.

## Step 2: Fetch threads

Inline threads, via GraphQL — the only call that returns both the thread IDs
needed to resolve and the `databaseId` needed to reply:

```bash
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr=$PR -f query='
query($owner:String!, $repo:String!, $pr:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          id isResolved isOutdated path line
          comments(first:50) {
            nodes { databaseId author { login } body url createdAt }
          }
        }
      }
    }
  }
}'
```

CodeRabbit bodies are long — embedded shell scripts and full web-search
transcripts. Write the response to a file under `$PAPERCLIP_RUN_SCRATCH_DIR`,
print a one-line summary per thread first, then read bodies deliberately.
Dumping every body at once burns a lot of context for little signal.

Filter to `isResolved: false`. Keep unresolved reviewer replies on an
already-answered thread — those are pushback, not new findings.

Conversation-level comments are separate and cannot be resolved:

```bash
gh api "repos/$OWNER/$REPO/issues/$PR/comments?per_page=100" \
  --jq '.[] | select(.user.login | startswith("coderabbitai")) | {id, body, html_url}'
```

## Step 4: Verify — do not trust the reviewer blindly

CodeRabbit cites docs and web searches that are often approximately right but
wrong on version specifics. Check the claim against the **locked** dependency
rather than the documentation:

```bash
grep -n "^    <gem> (" Gemfile.lock
find / -path /proc -prune -o -name "<file>.rb" -path "*<gem>*" -print 2>/dev/null
```

Reading the installed gem source settles a version-behaviour argument in one
command. Also confirm the flagged code still exists — `isOutdated: true` threads
usually point at something that has already moved.

Verdict per thread, one line:

| Verdict | When |
|---|---|
| **FIX** | Real bug, security gap, or clearly better idiom that matches repo conventions. |
| **DECLINE** | False positive, stale context, or conflicts with an intentional decision. |
| **DEFER** | Valid but out of scope — reply with the follow-up plan, then resolve. |

### The most common miss: right diagnosis, wrong remedy

Bots reliably identify a real risk and then propose a remedy whose blast radius
is far larger than the risk. The recurring shape is "fail fast at boot" applied
to a dormant, non-critical subsystem, which converts a silent gap in an unused
feature into a total outage on the next deploy.

Neither FIX-as-proposed nor DECLINE is right there. Keep the diagnosis, pick a
proportionate remedy — usually warn loudly at the earliest point a human will
see it — and say in the reply why you rejected the proposed remedy
specifically, citing the convention in this repo that you matched instead.

## Step 5a: FIX

Smallest change that addresses the concern; no unrelated cleanups. One
exception: if the identical defect sits a few lines from the flagged one, fix
both and say so in the reply. Leaving a known footgun next to a fixed one is
worse than a marginally wider diff.

Lint and test only the touched area. In an agent workspace the bundle is often
not installed at the default path, but a previous run's bundle is reusable:

```bash
ls -d /tmp/paperclip-run-*/bundle
BUNDLE_PATH=<that path> bundle exec rubocop <file>
bash -n bin/<script>
```

Commit with the discussion URL in the trailer, then `git push`. Never
`--force`, never `--no-verify`, never amend a commit that is already pushed.

## Step 5b: Reply

Inline thread — reply to the **first** comment's `databaseId`:

```bash
gh api -X POST "repos/$OWNER/$REPO/pulls/$PR/comments/$COMMENT_DATABASE_ID/replies" \
  -f body="$(cat <<'EOF'
<reason>
EOF
)"
```

Always a quoted heredoc. Replies contain backticks and `$`; inside a
double-quoted string the shell eats them and the API stores the mangled text
without complaint.

A conversation comment has no reply endpoint — post a new issue comment that
links back to it.

Reply content:

- First line: the verdict, and the commit SHA if there is one.
- The reason, grounded in this code, this repo's conventions, or the source you
  read. "Not applicable" is not a reason.
- Two sentences for a straightforward FIX. A declined finding earns more: name
  the risk you agree with, then the remedy you rejected and why.

## Step 7: Resolve

```bash
gh api graphql -F threadId="$THREAD_ID" -f query='
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) { thread { id isResolved } }
}'
```

Resolve after the fix is pushed, or after the declining reply is posted. Never
resolve without a commit or a reply behind it — the thread is the audit trail.

Two rounds of pushback is the limit. If the reviewer restates a concern you have
already answered with evidence, reply once more and resolve.

## Step 9: Report

Fixed (with SHAs) / declined (one line each) / deferred (with links) / still
open. If the PR is now gated on a human, say what is waiting on them.

## Anti-patterns

- Applying every suggestion without verifying it. Many are stylistic or wrong.
- Resolving a thread with no reply and no commit behind it.
- Force-pushing or amending to fold in review fixes.
- Bundling unrelated refactors into a "review fix" commit.
- Generic replies: "won't fix", "not applicable", "by design", with no reason.
- Merging the PR because its threads are now clear. Merge is a separate
  decision and usually the user's.
