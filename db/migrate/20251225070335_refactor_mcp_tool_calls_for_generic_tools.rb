class RefactorMcpToolCallsForGenericTools < ActiveRecord::Migration[8.1]
  def change
    remove_index :mcp_tool_calls, [:tool_name, :analysis_type]
    remove_index :mcp_tool_calls, :analysis_type
    remove_column :mcp_tool_calls, :analysis_type, :string
    rename_column :mcp_tool_calls, :filters, :parameters
  end
end
