import React, { useRef, useState } from "react";
import { Outlet, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "./Loader";
import Player from "./Player";
import AppModal from "./AppModal";

const Layout = ({ user, setUser, onLogout }) => {
  const navigation = useNavigation();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalContent, setModalContent] = useState(null);
  const [currentPlaylist, setCurrentPlaylist] = useState([]);
  const [customPlaylist, setCustomPlaylist] = useState(null);
  const [activeTrack, setActiveTrack] = useState(null);
  const [currentTime, setCurrentTime] = useState(0);
  const audioRef = useRef(null);

  const playTrack = (playlist, track, autoplay = false) => {
    if (currentPlaylist.length > 0 && autoplay) return;
    setCurrentPlaylist(playlist);
    setActiveTrack(track);
  };

  const openModal = (content) => {
    setModalContent(content);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setModalContent(null);
  };

  return (
    <>
      {navigation.state === 'loading' && <Loader />}
      <Navbar user={user} onLogout={onLogout} />
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{
          currentPlaylist,
          customPlaylist,
          setCustomPlaylist,
          activeTrack,
          playTrack,
          audioRef,
          currentTime,
          setCurrentTime,
          openModal,
          user,
          setUser
        }} />
      </main>
      <Footer />
      <Player
          currentPlaylist={currentPlaylist}
          activeTrack={activeTrack}
          setActiveTrack={setActiveTrack}
          audioRef={audioRef}
          setCurrentTime={setCurrentTime}
      />
      <AppModal
        isOpen={isModalOpen}
        onRequestClose={closeModal}
        modalContent={modalContent}
      />
    </>
  );
};

export default Layout;
