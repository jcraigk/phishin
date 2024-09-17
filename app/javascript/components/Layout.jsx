import React, { useState } from "react";
import { Outlet, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "./Loader";
import Player from "./Player";

const Layout = ({ user, onLogout, location: ssrLocation }) => {
  const navigation = useNavigation();

  const [currentPlaylist, setCurrentPlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);

  const playTrack = (playlist, track, autoplay = false) => {
    if (currentPlaylist.length > 0 && autoplay) return;
    setCurrentPlaylist(playlist);
    setActiveTrack(track);
  };

  return (
    <>
      {navigation.state === 'loading' && <Loader />}
      <Navbar user={user} onLogout={onLogout} />
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{ currentPlaylist, activeTrack, playTrack }} />
      </main>
      <Footer />
      {activeTrack && (
        <Player
          currentPlaylist={currentPlaylist}
          activeTrack={activeTrack}
          setActiveTrack={setActiveTrack}
        />
      )}
    </>
  );
};

export default Layout;
