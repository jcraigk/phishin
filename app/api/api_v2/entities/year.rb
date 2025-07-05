class ApiV2::Entities::Year < ApiV2::Entities::Base
  expose \
    :period,
    documentation: {
      type: "String",
      desc: 'The year or period being represented (e.g. "1997", "1983-1987")'
    }

  expose \
    :shows_count,
    documentation: {
      type: "Integer",
      desc: "Number of shows that were performed during this period"
    }

  expose \
    :shows_with_audio_count,
    documentation: {
      type: "Integer",
      desc: "Number of shows that were performed during this period for which known recordings exist"
    }

  expose \
    :shows_duration,
    documentation: {
      type: "Integer",
      desc: "Total duration in milliseconds of all shows performed during this period"
    }

  expose \
    :venues_count,
    documentation: {
      type: "Integer",
      desc: "Unique number of venues that shows were performed at during this period"
    }

  expose \
    :venues_with_audio_count,
    documentation: {
      type: "Integer",
      desc: "Unique number of venues that shows with audio were performed at during this period"
    }

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
