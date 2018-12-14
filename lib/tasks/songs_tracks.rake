# frozen_string_literal: true
namespace :dupes do
  desc 'Find and destroy dupes'
  task dupes: :environment do
    SongsTrack.select(:track_id, :song_id).group(:track_id, :song_id).having('count(*) > 1').each do |st|
      SongsTrack.where(song_id: st.song_id, track_id: st.track_id).each_with_index do |st2, idx|
        next print '.' if idx.zero?
        st2.destroy
        print '*'
      end
    end

    TrackTag.select(:track_id, :tag_id).group(:track_id, :tag_id).having('count(*) > 1').each do |tt|
      TrackTag.where(tag_id: tt.tag_id, track_id: tt.track_id).each_with_index do |tt2, idx|
        next print '.' if idx.zero?
        tt2.destroy
        print '*'
      end
    end

    Playlist.select(:name).group(:name).having('count(*) > 1').each do |p|
      Playlist.where(name: p.name).each_with_index do |p2, idx|
        next print '.' if idx.zero?
        p2.update_column(:name, p2.name + 'b')
        print '*'
      end
    end
  end
end
