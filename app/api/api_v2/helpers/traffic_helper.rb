module ApiV2::Helpers::TrafficHelper
  def track_traffic
    return if request.path.include?("/swagger_doc")
    web = request.get_header("HTTP_X_PHISHIN_CLIENT").present?
    TrafficBuffer.increment(
      client: web ? "web" : "api",
      logged_in: current_user.present?,
      route: route.origin,
      ip: web ? "" : remote_ip,
      user_agent: web ? "" : request.user_agent.to_s
    )
  end

  private

  def remote_ip
    (env["action_dispatch.remote_ip"] || request.ip).to_s
  end
end
