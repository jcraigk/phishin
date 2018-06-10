# frozen_string_literal: true
class PagesController < ApplicationController
  def legal_stuff
    render_xhr_without_layout
  end

  def contact_us
    render_xhr_without_layout
  end

  def api_docs
    render_xhr_without_layout
  end
end
