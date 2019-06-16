# frozen_string_literal: true
class StaticPagesController < ApplicationController
  def faq
    render_xhr_without_layout
  end

  def contact
    render_xhr_without_layout
  end

  def api_docs
    render_xhr_without_layout
  end

  def tagin_project
    render_xhr_without_layout
  end
end
