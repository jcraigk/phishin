module Admin::Blobs
  def self.purge_if_unreferenced(blob)
    return if ActiveStorage::Attachment.where(blob_id: blob.id).exists?
    blob.purge
  end

  def self.detach(attachment)
    blob = attachment.blob
    attachment.destroy
    purge_if_unreferenced(blob)
  end
end
