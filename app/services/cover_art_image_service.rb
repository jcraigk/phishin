class CoverArtImageService < ApplicationService
  param :show
  option :dry_run, default: -> { false }
  option :source_blob_key, default: -> { nil }
  option :edit_prompt, default: -> { nil }
  option :prompt_override, default: -> { nil }
  option :model, default: -> { nil }

  MODELS = %w[
    openai/gpt-image-2.6-sunburst
    openai/gpt-image-2.6-sunburst:xhigh
    openai/gpt-image-2.6-sunburst:max
    google/gemini-nano-banana-2.1
    google/gemini-3.1-flash-image
    google/gemini-3-pro-image
  ].freeze
  DEFAULT_QUALITY = "high".freeze

  def self.default_model
    ENV.fetch("COVER_ART_IMAGE_MODEL", MODELS.first)
  end

  def call
    generate_and_save_cover_art
  end

  private

  def editing?
    source_blob_key.present? && edit_prompt.present?
  end

  def image_model
    @image_model ||= model.presence || self.class.default_model
  end

  def api_model
    image_model.split(":").first
  end

  def quality
    image_model.split(":")[1] || DEFAULT_QUALITY
  end

  def generate_and_save_cover_art
    if show.cover_art_parent_show_id && !editing?
      parent_show = Show.find(show.cover_art_parent_show_id)
      show.cover_art.attach(parent_show.cover_art.blob) unless dry_run
      return
    end

    result = generate_image
    url = upload_candidate(result.b64, result.cost)
    show.attach_cover_art_by_url(url) unless dry_run
    url
  end

  def generate_image
    if editing?
      OpenRouter.image(model: api_model, quality:, prompt: edit_prompt, source_url: source_data_url)
    else
      OpenRouter.image(model: api_model, quality:, prompt: generation_prompt)
    end
  rescue OpenRouter::Error => e
    raise "Failed to generate cover art: #{e.message}"
  end

  def generation_prompt
    prompt_override.presence || show.cover_art_prompt
  end

  def source_blob
    @source_blob ||= ActiveStorage::Blob.find_by!(key: source_blob_key)
  end

  def source_metadata
    return {} unless editing?
    source_blob.metadata
  end

  def source_data_url
    content_type =
      source_blob.content_type.to_s.start_with?("image/") ? source_blob.content_type : "image/png"
    "data:#{content_type};base64,#{Base64.strict_encode64(source_blob.download)}"
  end

  def base_prompt
    return generation_prompt unless editing?
    source_metadata["prompt"].presence || show.cover_art_prompt
  end

  def edit_chain
    return [] unless editing?
    Array(source_metadata["edits"]) + [ edit_prompt ]
  end

  def upload_candidate(b64, cost)
    metadata = { "model" => image_model }
    metadata["prompt"] = base_prompt if base_prompt.present?
    metadata["edits"] = edit_chain if edit_chain.any?
    metadata["cost"] = cost.round(4) if cost.present?
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(b64)),
      filename: "cover_art_candidate_#{SecureRandom.hex}.png",
      content_type: "image/png",
      metadata:
    )
    "#{App.base_url}/blob/#{blob.key}.png"
  end
end
