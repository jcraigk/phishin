class RemoveUserFieldsFromMcpToolCalls < ActiveRecord::Migration[8.1]
  def change
    remove_reference :mcp_tool_calls, :user, foreign_key: true
    remove_column :mcp_tool_calls, :user_agent, :string
    remove_column :mcp_tool_calls, :ip_address, :string
  end
end
