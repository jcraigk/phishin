Rails.application.configure do
  config.attachment_backup = {
    attachments: [
      { model: "Show", attachment: "album_cover" },
      { model: "Show", attachment: "cover_art" },
      { model: "Track", attachment: "mp3_audio" },
      { model: "Track", attachment: "png_waveform" }
    ]
  }
end
