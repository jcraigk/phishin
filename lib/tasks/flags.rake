# frozen_string_literal: true
namespace :flags do
  desc 'Set SBD flag on all shows based on presence of SBD tag'
  task sync_sbd_to_tags: :environment do
    tag = Tag.where(name: 'SBD').first

    Show.all.map { |show| show.update_attributes(sbd: false) }

    Show.includes(:tags).find_each do |show|
      show.update_attributes(sbd: true) if show.tags.include?(tag)
    end
  end
end
