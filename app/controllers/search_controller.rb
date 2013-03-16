class SearchController < ApplicationController

  def search
    render layout: false if request.xhr?
  end
  
  def results
    render layout: false if request.xhr?
  end

end