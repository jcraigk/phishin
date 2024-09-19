import React, { useState, useRef } from "react";
import { Outlet, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "./Loader";
import Player from "./Player";
import TaperNotesModal from "./TaperNotesModal";

const Layout = ({ user, onLogout }) => {
  const navigation = useNavigation();
  const [isTaperNotesModalOpen, setIsTaperNotesModalOpen] = useState(false);
  const [taperNotesShow, setTaperNotesShow] = useState(null);
  const [currentPlaylist, setCurrentPlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);
  const [currentTime, setCurrentTime] = useState(0);
  const audioRef = useRef(null);

  const playTrack = (playlist, track, autoplay = false) => {
    if (currentPlaylist.length > 0 && autoplay) return;
    setCurrentPlaylist(playlist);
    setActiveTrack(track);
  };

  const openTaperNotesModal = (show) => {
    setTaperNotesShow(show);
    setIsTaperNotesModalOpen(true);
  };

  const closeTaperNotesModal = () => {
    setIsTaperNotesModalOpen(false);
  };

  return (
    <>
      {navigation.state === 'loading' && <Loader />}
      <Navbar user={user} onLogout={onLogout} />
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{ currentPlaylist, activeTrack, playTrack, audioRef, currentTime, setCurrentTime, openTaperNotesModal }} />
      </main>
      <Footer />
      {activeTrack && (
        <Player
          currentPlaylist={currentPlaylist}
          activeTrack={activeTrack}
          setActiveTrack={setActiveTrack}
          audioRef={audioRef}
          setCurrentTime={setCurrentTime}
        />
      )}
      <TaperNotesModal
        isOpen={isTaperNotesModalOpen}
        onRequestClose={closeTaperNotesModal}
        show={taperNotesShow}
      />
    </>
  );
};

export default Layout;
