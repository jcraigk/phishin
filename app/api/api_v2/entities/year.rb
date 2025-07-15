class ApiV2::Entities::Year < ApiV2::Entities::Base
  include ApiV2::Concerns::CountFieldsWithAudio

  expose \
    :period,
    documentation: {
      type: "String",
      desc: 'The year or period being represented (e.g. "1997", "1983-1987")'
    }

  expose_count_fields_with_audio :shows_count, "shows that were performed during this period"

  expose \
    :shows_duration,
    documentation: {
      type: "Integer",
      desc: "Total duration in milliseconds of all shows performed during this period"
    }

  expose_count_fields_with_audio :venues_count, "unique venues that shows were performed at during this period"

  expose \
    :era,
    documentation: {
      type: "String",
      desc: 'The era associated with this period ("1.0", "2.0", etc.)'
    }

  expose \
    :cover_art_urls,
    documentation: {
      type: "Array",
      desc: "Cover art URLs taken from the last show in the period"
    }
end
