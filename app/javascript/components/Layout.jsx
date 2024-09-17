import React, { useState, useEffect } from "react";
import { Outlet, useLocation, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "./Loader";
import Player from "./Player";
import { useNotification } from "./NotificationContext";

const Layout = ({ user, onLogout, location: ssrLocation }) => {
  const { notification, clearNotification } = useNotification();
  const navigation = useNavigation();

  const clientLocation = useLocation();
  const location = typeof window === "undefined" ? ssrLocation : clientLocation;

  useEffect(() => {
    clearNotification();
  }, [location.pathname]);

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
      {notification && (
        <div className={`notification is-${notification.type}`}>
          <button className="delete" onClick={clearNotification}></button>
          {notification.message}
        </div>
      )}
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
