# frozen_string_literal: true

class ReplaceApiTokenScopeWithPermissions < ActiveRecord::Migration[8.1]
  # The full grantable set as of this migration, enumerated rather than a
  # wildcard: a read_write token becomes a token that may invoke exactly these
  # actions, so a *future* action is not silently granted to it — the
  # denied-by-construction property must hold for existing tokens too.
  #
  # Hardcoded literals (not computed from Rails.application.routes at run time)
  # so the backfill is reproducible on a fresh database and independent of the
  # app code loaded when the migration happens to run. Kept in sync with
  # ApiToken::PermissionRegistry by a one-time authoring check, not a standing
  # assertion (which would break the first time a route is added).
  FULL = %w[
    invoice_notifications#approve
    invoice_notifications#approve_all
    invoice_notifications#cancel
    invoice_notifications#index
    invoice_notifications#retry
    invoice_templates#create
    invoice_templates#destroy
    invoice_templates#preview
    invoice_templates#update
    invoices#audit
    invoices#create
    invoices#index
    invoices#show
    invoices#update
    leases#create
    leases#destroy
    leases#index
    leases#show
    leases#update
    owners#create
    owners#destroy
    owners#index
    owners#show
    owners#update
    payments#create
    payments#index
    payments#show
    payments#update
    properties#create
    properties#destroy
    properties#index
    properties#show
    properties#update
    reminder_steps#create
    reminder_steps#destroy
    reminder_steps#update
    reports#index
    reports#outstanding
    reports#revenue
    reports#taxes
    tenants#create
    tenants#destroy
    tenants#index
    tenants#show
    tenants#update
    user_associations#create
    user_associations#destroy
    users#create
    users#destroy
    users#index
    users#show
    users#update
    versions#destroy
    versions#index
    versions#show
  ].freeze

  # The GET/HEAD-reachable subset — reproduces the old read_only scope exactly.
  READ = %w[
    invoice_notifications#index
    invoices#audit
    invoices#index
    invoices#show
    leases#index
    leases#show
    owners#index
    owners#show
    payments#index
    payments#show
    properties#index
    properties#show
    reports#index
    reports#outstanding
    reports#revenue
    reports#taxes
    tenants#index
    tenants#show
    users#index
    users#show
    versions#index
    versions#show
  ].freeze

  def up
    add_column :api_tokens, :permissions, :jsonb, null: false, default: []
    add_column :api_tokens, :preset, :string

    # scope: read_write (0) -> full grant; read_only (1) -> read subset. Also
    # record the display-only preset label matching each backfilled set.
    execute("UPDATE api_tokens SET permissions = '#{FULL.to_json}'::jsonb, preset = 'full' WHERE scope = 0")
    execute("UPDATE api_tokens SET permissions = '#{READ.to_json}'::jsonb, preset = 'read_only' WHERE scope = 1")

    remove_column :api_tokens, :scope
  end

  def down
    add_column :api_tokens, :scope, :integer, null: false, default: 0

    # Fail closed: only a token holding exactly the full grant returns to
    # read_write. Anything narrower (a read token, or a custom grant that never
    # had a scope equivalent) lands on read_only, so an emergency rollback
    # never accidentally restores full mutation rights.
    execute("UPDATE api_tokens SET scope = 1")
    execute("UPDATE api_tokens SET scope = 0 WHERE permissions = '#{FULL.to_json}'::jsonb")

    remove_column :api_tokens, :preset
    remove_column :api_tokens, :permissions
  end
end
