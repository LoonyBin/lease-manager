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

  # A legacy row (with `scope`, without `permissions`/`preset`) written in raw
  # SQL rather than through the model.
  def insert_legacy_token(name, scope)
    connection.execute(<<~SQL.squish)
      INSERT INTO api_tokens (name, token_digest, scope, user_id, created_at, updated_at)
      VALUES (#{connection.quote(name)}, #{connection.quote(name)}, #{scope}, #{user.id}, NOW(), NOW())
    SQL
  end

  def backfilled(name)
    connection.select_one("SELECT permissions, preset FROM api_tokens WHERE name = #{connection.quote(name)}")
  end
end
