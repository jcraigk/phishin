class Admin::StagingPreviewsController < ApplicationController
  include ActiveStorage::FileServer

  PURPOSE = :staging_preview
  TTL = 1.day

  def self.token_for(show)
    verifier.generate(show.id, purpose: PURPOSE, expires_in: TTL)
  end

  def self.show_from(token)
    show_id = verifier.verified(token.to_s, purpose: PURPOSE)
    show_id && Show.find_by(id: show_id)
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end

  def show
    show = self.class.show_from(params[:token])
    return head(:not_found) if show.nil?
    path = Admin::StagingDir.new(show).preview
    return head(:not_found) unless path.exist?
    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Cache-Control"] = "private, no-store"
    serve_file path.to_s, content_type: "audio/mpeg", disposition: "inline"
  end
end
