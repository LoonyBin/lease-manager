# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260808000001_replace_api_token_scope_with_permissions")

# Coverage for the backfill — the migration's whole risk surface. Existing tokens
# carry only the legacy `scope` enum, and must come out the far side with an
# equivalent permission set (acceptance criteria: a read_write token behaves
# exactly as before, read_only stays expressible). We reverse to the legacy
# schema, seed real read_write/read_only rows, run `up`, and assert the resulting
# permissions + preset — the mapping no request spec can reach once `scope` is
# gone.
#
# Postgres DDL is transactional, so migrating down and back up runs inside the
# example's own (transactional-fixtures) transaction and rolls back with it —
# nothing leaks to the shared schema. `down` then `up` is a net no-op on the
# schema regardless; the after hook only drops ActiveRecord's in-memory column
# cache so later examples see the real columns again.
RSpec.describe ReplaceApiTokenScopeWithPermissions do
  let(:migration) { described_class.new }
  let(:connection) { ActiveRecord::Base.connection }
  let!(:user) { create(:user) }

  around do |example|
    was_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = was_verbose
  end

  after { ApiToken.reset_column_information }

  # Reverse to the legacy `scope` schema, seed a read_write (0) and a read_only
  # (1) row directly (the model already expects the post-migration columns, so
  # the legacy shape is raw SQL), then run the backfill under test.
  before do
    migration.migrate(:down)
    ApiToken.reset_column_information
    insert_legacy_token("legacy_rw", 0)
    insert_legacy_token("legacy_ro", 1)
    migration.migrate(:up)
  end

  it "backfills a legacy read_write row to the full grant and preset", :aggregate_failures do
    row = backfilled("legacy_rw")
    expect(JSON.parse(row["permissions"])).to eq(described_class::FULL)
    expect(row["preset"]).to eq("full")
  end

  it "backfills a legacy read_only row to the read subset and preset", :aggregate_failures do
    row = backfilled("legacy_ro")
    expect(JSON.parse(row["permissions"])).to eq(described_class::READ)
    expect(row["preset"]).to eq("read_only")
  end

  # `down` derives scope back from permissions, fail-closed: only the exact FULL
  # grant returns to read_write; anything narrower lands on read_only, so an
  # emergency rollback never restores full mutation rights to a narrow token.
  # The before hook leaves us in the post-migration (up) schema, so we seed a
  # narrow custom grant here, roll back, and assert the derived scope.
  it "rolls a narrow custom grant back to read_only, and the full grant to read_write", :aggregate_failures do
    insert_custom_token("narrow_custom", %w[invoices#index invoices#show payments#create])
    migration.migrate(:down)
    ApiToken.reset_column_information
    expect(legacy_scope("narrow_custom")).to eq(1) # read_only, fail-closed
    expect(legacy_scope("legacy_rw")).to eq(0)     # the exact FULL grant -> read_write
  end

  # A legacy row (with `scope`, without `permissions`/`preset`) written in raw
  # SQL rather than through the model.
  def insert_legacy_token(name, scope)
    connection.execute(<<~SQL.squish)
      INSERT INTO api_tokens (name, token_digest, scope, user_id, created_at, updated_at)
      VALUES (#{connection.quote(name)}, #{connection.quote(name)}, #{scope}, #{user.id}, NOW(), NOW())
    SQL
  end

  # A post-migration token (permissions/preset, no scope) with a custom grant,
  # written in raw SQL so the down direction can be exercised on it.
  def insert_custom_token(name, permissions)
    connection.execute(<<~SQL.squish)
      INSERT INTO api_tokens (name, token_digest, permissions, preset, user_id, created_at, updated_at)
      VALUES (#{connection.quote(name)}, #{connection.quote(name)}, #{connection.quote(permissions.to_json)}::jsonb,
              NULL, #{user.id}, NOW(), NOW())
    SQL
  end

  def backfilled(name)
    connection.select_one("SELECT permissions, preset FROM api_tokens WHERE name = #{connection.quote(name)}")
  end

  # scope after a rollback, cast to Integer (0 = read_write, 1 = read_only).
  # Deliberately nil-safe rather than nil-coercing: a bare `.to_i` turns a
  # missing row into 0, which would let `eq(0)` pass vacuously when the row
  # never made it back. nil never equals 0, so a vanished row now fails loudly.
  def legacy_scope(name)
    connection.select_value("SELECT scope FROM api_tokens WHERE name = #{connection.quote(name)}")&.to_i
  end
end
