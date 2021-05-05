# frozen_string_literal: true
class PhishinUploader < Shrine
  protected

  # Example: ID 34123 => 000/034/123
  def partition_path(record)
    record.id.to_s.rjust(9, '0').gsub(/(.{3})(?=.)/, '\1/\2')
  end
end
