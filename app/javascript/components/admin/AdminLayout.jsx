import React, { createContext, useEffect, useState } from "react";
import { Outlet, useNavigate } from "react-router";
import Player from "../controls/Player";

export const AdminPlayerContext = createContext(null);

// Only the admin gate remains here; navigation lives in the site's own menu.
const AdminLayout = () => {
  const navigate = useNavigate();
  const isAdmin = typeof window !== "undefined" && localStorage.getItem("admin") === "true";
  const [activePlaylist, setActivePlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);
  const [shouldAutoplay, setShouldAutoplay] = useState(true);
  const [isPlaying, setIsPlaying] = useState(false);

  useEffect(() => {
    if (!isAdmin) navigate("/login");
  }, [isAdmin, navigate]);

  if (!isAdmin) return null;

  const playTrack = (playlist, track, autoplay = true) => {
    setActivePlaylist(playlist);
    setActiveTrack(track);
    setShouldAutoplay(autoplay);
  };

  return (
    <AdminPlayerContext.Provider value={{ playTrack, activeTrack, isPlaying }}>
      <div className="admin-layout">
        <main className="admin-content">
          <Outlet />
        </main>
      </div>
      <Player
        activePlaylist={activePlaylist}
        activeTrack={activeTrack}
        setActiveTrack={setActiveTrack}
        customPlaylist={null}
        openAppModal={() => {}}
        shouldAutoplay={shouldAutoplay}
        setShouldAutoplay={setShouldAutoplay}
        onPlayingChange={setIsPlaying}
      />
    </AdminPlayerContext.Provider>
  );
};

export default AdminLayout;
