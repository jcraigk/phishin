module HasAudio
  extend ActiveSupport::Concern

  included do
    private

    def audio_attachment_url(attachment_name)
      attachment = public_send(attachment_name)
      if attachment.attached?
        key = attachment.blob.key
        "#{App.content_base_url}/blob/#{key}"
      else
        nil
      end
    end

    def waveform_attachment_url(attachment_name)
      attachment = public_send(attachment_name)
      if attachment.attached?
        key = attachment.blob.key
        "#{App.content_base_url}/blob/#{key}"
      else
        nil
      end
    end
  end
end
