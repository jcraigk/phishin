module ApiV2::Concerns::CountFieldsWithAudio
  extend ActiveSupport::Concern

  class_methods do
    def expose_count_fields_with_audio(base_field, description_base)
      expose base_field,
             documentation: {
               type: "Integer",
               desc: "Number of #{description_base}"
             }

      audio_field = "#{base_field.to_s.sub('_count', '')}_with_audio_count".to_sym
      expose audio_field,
             documentation: {
               type: "Integer",
               desc: "Number of #{description_base} that have audio"
             }
    end
  end
end
