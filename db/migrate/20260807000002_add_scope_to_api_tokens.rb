# frozen_string_literal: true

class AddScopeToApiTokens < ActiveRecord::Migration[8.0]
  # default: 0 (= read_write) backfills existing tokens with no behaviour
  # change. Scope is read off an already-loaded token, never queried by, so
  # no index.
  def change
    add_column :api_tokens, :scope, :integer, null: false, default: 0
  end
end
