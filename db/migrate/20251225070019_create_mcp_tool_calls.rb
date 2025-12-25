class CreateMcpToolCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_tool_calls do |t|
      t.string :tool_name, null: false
      t.string :analysis_type
      t.jsonb :filters, default: {}
      t.jsonb :result_summary, default: {}
      t.integer :result_count
      t.integer :duration_ms
      t.string :error_message
      t.string :user_agent
      t.string :ip_address
      t.references :user, foreign_key: true, null: true

      t.timestamps
    end

    add_index :mcp_tool_calls, :tool_name
    add_index :mcp_tool_calls, :analysis_type
    add_index :mcp_tool_calls, :created_at
    add_index :mcp_tool_calls, [:tool_name, :analysis_type]
  end
end
