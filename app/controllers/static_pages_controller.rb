class StaticPagesController < ApplicationController
  def faq
    render_view
  end

  def privacy_policy
    render_view
  end

  def terms_of_service
    render_view
  end

  def contact_info
    render_view
  end

  def api_docs
    render_view
  end

  def tagin_project
    render_view
  end
end
