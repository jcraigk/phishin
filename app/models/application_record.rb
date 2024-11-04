class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def blob_url(attachment, variant: nil, placeholder: nil)
    if attachment.attached?
      key = variant ? attachment.variant(variant).processed.key : attachment.blob.key
      "#{App.content_base_url}/blob/#{key}"
    elsif placeholder
      "/placeholders/#{placeholder}"
    end
  rescue ActiveStorage::FileNotFoundError
    nil
  end
end
