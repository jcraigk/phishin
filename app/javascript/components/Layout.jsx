import React, { useState, useEffect } from "react";
import { Outlet, useLocation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Player from "./Player";
import { useNotification } from "./NotificationContext";

const Layout = ({ appName, user, onLogout }) => {
  const { notification, clearNotification } = useNotification();
  const location = useLocation();

  const staticLinks = [
    { path: "/faq", label: "FAQ" },
    { path: "/api-docs", label: "API" },
    { path: "/tagin-project", label: "Tagin' Project" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
  ];

  useEffect(() => {
    clearNotification();
  }, [location.pathname]);

  const [currentPlaylist, setCurrentPlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);

  const playTrack = (playlist, track) => {
    setCurrentPlaylist(playlist);
    setActiveTrack(track);
  };

  return (
    <>
      <Navbar appName={appName} user={user} onLogout={onLogout} staticLinks={staticLinks} />
      {notification && (
        <div className={`notification is-${notification.type}`}>
          <button className="delete" onClick={clearNotification}></button>
          {notification.message}
        </div>
      )}
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{ currentPlaylist, activeTrack, playTrack }} />
      </main>
      <Footer staticLinks={staticLinks} activeTrack={activeTrack} />
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
