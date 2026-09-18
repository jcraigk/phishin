class ApiV2::Admin::Traffic < ApiV2::Admin::Base
  TOP_LIMIT = 200

  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    desc "Summarize web and API traffic", hidden: true
    params do
      optional :window, type: String, default: "30d", values: ::TrafficCount::WINDOWS.keys
      optional :client, type: String, values: ::TrafficCount::CLIENTS
      optional :ip, type: String
    end
    get :traffic do
      bucket = ::TrafficCount::WINDOWS.fetch(params[:window]).last
      from = ::TrafficCount.window_start(params[:window])
      scope = ::TrafficCount.where(hour: from..)
      scope = scope.where(client: params[:client]) if params[:client].present?
      scope = scope.where(ip: params[:ip]) if params[:ip].present?

      {
        window: params[:window],
        bucket:,
        client: params[:client].presence,
        ip: params[:ip].presence,
        total: scope.sum(:count),
        series: ::TrafficCount.series(scope, from, bucket),
        clients: ::TrafficCount::CLIENTS.index_with { 0 }.merge(scope.group(:client).sum(:count)),
        logged_in: { true => 0, false => 0 }.merge(scope.group(:logged_in).sum(:count)),
        routes: top(scope, :route),
        ips: top(scope.where.not(ip: ""), :ip),
        user_agents: top(scope.where.not(user_agent: ""), :user_agent),
        distinct: {
          routes: scope.distinct.count(:route),
          ips: scope.where.not(ip: "").distinct.count(:ip),
          user_agents: scope.where.not(user_agent: "").distinct.count(:user_agent)
        }
      }
    end

    desc "Export the full traffic breakdown for a window as a JSON file", hidden: true
    params do
      optional :window, type: String, default: "30d", values: ::TrafficCount::WINDOWS.keys
      optional :client, type: String, values: ::TrafficCount::CLIENTS
      optional :ip, type: String
    end
    get "traffic/export" do
      name = [ "phishin-traffic", params[:window], params[:client].presence, params[:ip].presence, Time.current.strftime("%Y%m%d-%H%M") ]
               .compact.join("-").gsub(/[^\w.-]/, "_")
      header "Content-Disposition", "attachment; filename=\"#{name}.json\""
      TrafficExport.call(window: params[:window], client: params[:client], ip: params[:ip])
    end
  end

  helpers do
    def top(scope, column)
      scope.group(column)
           .sum(:count)
           .sort_by { |value, count| [ -count, value ] }
           .first(TOP_LIMIT)
           .map { |value, count| { value:, count: } }
    end
  end
end
