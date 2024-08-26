class GrapeApi::Entities::Year < GrapeApi::Entities::Base
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
      desc: "Number of shows that occurred during this period"
    }

  expose \
    :era,
    documentation: {
      type: "String",
      desc: 'The era associated with this period ("1.0", "2.0", etc.)'
    }
end
