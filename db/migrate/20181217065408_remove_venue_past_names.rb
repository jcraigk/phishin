class RemoveVenuePastNames < ActiveRecord::Migration[5.2]
  def change
    remove_column :venues, :past_names, :string
  end
end
