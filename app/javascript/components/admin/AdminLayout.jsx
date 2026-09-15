import React, { createContext, useEffect, useState } from "react";
import { Outlet } from "react-router";
import Player from "../controls/Player";
import AdminTooltip from "./AdminTooltip";

export const AdminPlayerContext = createContext(null);

// The admin gate lives in the route loader, which 404s non-admins before this
// component mounts; navigation lives in the site's own menu.
const AdminLayout = () => {
  const isAdmin = typeof window !== "undefined" && localStorage.getItem("admin") === "true";
  const [activePlaylist, setActivePlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);
  const [shouldAutoplay, setShouldAutoplay] = useState(true);
  const [isPlaying, setIsPlaying] = useState(false);

  // Only one thing plays at a time: an audio element starting pauses every
  // other element and the bottom Player, which listens for the custom event.
  useEffect(() => {
    const onPlay = (e) => {
      if (!(e.target instanceof HTMLMediaElement)) return;
      document.querySelectorAll("audio").forEach((el) => {
        if (el !== e.target && !el.paused) el.pause();
      });
      window.dispatchEvent(new Event("phishin:pause-player"));
    };
    document.addEventListener("play", onPlay, true);
    return () => document.removeEventListener("play", onPlay, true);
  }, []);

  if (!isAdmin) return null;

  const handlePlayingChange = (playing) => {
    setIsPlaying(playing);
    if (playing) {
      document.querySelectorAll("audio").forEach((el) => {
        if (!el.paused) el.pause();
      });
    }
  };

  const playTrack = (playlist, track, autoplay = true) => {
    setActivePlaylist(playlist);
    setActiveTrack(track);
    setShouldAutoplay(autoplay);
  };

  return (
    <AdminPlayerContext.Provider value={{ playTrack, activeTrack, isPlaying }}>
      <div className="admin-layout">
        <AdminTooltip />
        <main className="admin-content">
          <Outlet />
        </main>
      </div>
      {activeTrack && (
        <Player
          activePlaylist={activePlaylist}
          activeTrack={activeTrack}
          setActiveTrack={setActiveTrack}
          customPlaylist={null}
          openAppModal={() => {}}
          shouldAutoplay={shouldAutoplay}
          setShouldAutoplay={setShouldAutoplay}
          onPlayingChange={handlePlayingChange}
          onClose={() => {
            setActiveTrack(null);
            setActivePlaylist([]);
            setIsPlaying(false);
          }}
        />
      )}
    </AdminPlayerContext.Provider>
  );
};

export default AdminLayout;
