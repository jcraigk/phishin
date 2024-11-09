class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def blob_url(attachment, variant: nil, placeholder: nil, ext: nil)
    if attachment.attached?
      key = variant ? attachment.variant(variant).processed.key : attachment.blob.key
      "#{App.content_base_url}/blob/#{key}#{".#{ext}" if ext}"
    elsif placeholder
      "/placeholders/#{placeholder}"
    end
  rescue ActiveStorage::FileNotFoundError
    nil
  end
end
