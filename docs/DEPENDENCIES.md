# Dependency updates

Lease Manager is a live service. Review dependency updates against the code that
uses them, their release notes, and CI on the update's current head. These rules
do not replace the repository's review, commit, or merge approval requirements.

## Merge eligibility

Merge only when **all** of these conditions hold and no escalation rule below
applies:

- Every CI check is green on the update's current head. A previous head's green
  checks or local test results do not substitute for current-head CI.
- The update is a patch or minor release.
- It does not change a version constraint in `Gemfile`. Treat a constraint edit
  as widening a major-version boundary and require maintainer review.
- The changelog has no breaking-change, removal, or deprecation entry affecting
  an API this codebase calls. Check the actual call sites before deciding.

## Always escalate; never merge as a routine update

Escalate these updates to the maintainer responsible for the application:

- A major update of any runtime gem.
- Any gem on the **money path** (invoice amounts, payments, or the ledger), at
  any semantic version level. A numeric or rounding change can surface as wrong
  money without failing a test. This includes `dentaku`, which evaluates invoice
  line-item amounts in
  [`app/services/invoice_templates/amount_evaluator.rb`](../app/services/invoice_templates/amount_evaluator.rb).
- CI that is red for a reason nobody can explain, or red after a rebase.
- Anything touching authentication, sessions, or file/blob storage.
- Anything touching production secrets or deploy configuration.

Distinguish development-only dependencies from runtime dependencies when
assessing risk. A test-tooling major that CI fully exercises can be lower risk
than a runtime patch, but development-only status does **not** by itself authorize
merging a major update.

## Dependabot queue

[`.github/dependabot.yml`](../.github/dependabot.yml) sets
`open-pull-requests-limit: 10` for both Bundler and GitHub Actions updates. Keep
the update queue below 10; queue pressure never overrides the merge or escalation
rules above.

The configured limit stops new **version-update** PRs for that ecosystem when
it is reached. Security-update PRs are excluded from that configured limit and
do not count toward it; monitor security updates as well. See GitHub's
[`open-pull-requests-limit` reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#open-pull-requests-limit).

See [Security tooling and review](SECURITY.md) for the CI scanners and
[Testing](TESTING.md) for application verification.
