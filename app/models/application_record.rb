class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def blob_url(attachment, variant = nil)
    return unless attachment.attached?
    key = variant ? attachment.variant(variant).processed.key : attachment.blob.key
    "#{App.content_base_url}/blob/#{key}"
  rescue ActiveStorage::FileNotFoundError
    nil
  end
end
