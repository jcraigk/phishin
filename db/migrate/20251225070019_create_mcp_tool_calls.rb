class CreateMcpToolCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_tool_calls do |t|
      t.string :tool_name, null: false
      t.jsonb :parameters, default: {}
      t.jsonb :result_summary, default: {}
      t.integer :result_count
      t.integer :duration_ms
      t.string :error_message

      t.timestamps
    end

    add_index :mcp_tool_calls, :tool_name
    add_index :mcp_tool_calls, :created_at
  end
end
