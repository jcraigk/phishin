module ApplicationHelper
  def json_ld_tag(graph)
    json = graph.to_json
      .gsub("<") { "\\u003c" }
      .gsub(">") { "\\u003e" }
      .gsub("&") { "\\u0026" }
    content_tag(:script, raw(json), type: "application/ld+json")
  end
end
