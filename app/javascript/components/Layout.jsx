import React, { useRef, useState } from "react";
import { Outlet, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "./Loader";
import Player from "./Player";
import AppModal from "./AppModal";
import DraftPlaylistModal from "./DraftPlaylistModal";

const Layout = ({ user, setUser, onLogout }) => {
  const navigation = useNavigation();
  const [isAppModalOpen, setIsAppModalOpen] = useState(false);
  const [appModalContent, setAppModalContent] = useState(null);
  const [isDraftPlaylistModalOpen, setIsDraftPlaylistModalOpen] = useState(false);
  const [activePlaylist, setActivePlaylist] = useState([]);
  const [customPlaylist, setCustomPlaylist] = useState(null);
  const [draftPlaylist, setDraftPlaylist] = useState([]);
  const [draftPlaylistMeta, setDraftPlaylistMeta] = useState({
    name: "",
    slug: "",
    description: "",
    published: false
  });
  const [activeTrack, setActiveTrack] = useState(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [isInputFocused, setIsInputFocused] = useState(false);
  const audioRef = useRef(null);

  const handleInputFocus = () => setIsInputFocused(true);
  const handleInputBlur = () => setIsInputFocused(false);

  const playTrack = (playlist, track, autoplay = false) => {
    if (activePlaylist.length > 0 && autoplay) return;
    setActivePlaylist(playlist);
    setActiveTrack(track);
  };

  const openAppModal = (content) => {
    setAppModalContent(content);
    setIsAppModalOpen(true);
  };

  const closeAppModal = () => {
    setIsAppModalOpen(false);
    setAppModalContent(null);
  };

  const openDraftPlaylistModal = () => {
    setIsDraftPlaylistModalOpen(true);
  };

  const closeDraftPlaylistModal = () => {
    setIsDraftPlaylistModalOpen(false);
  };

  return (
    <>
      {navigation.state === 'loading' && <Loader />}
      <Navbar
        user={user}
        onLogout={onLogout}
        handleInputFocus={handleInputFocus}
        handleInputBlur={handleInputBlur}
      />
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{
          activePlaylist,
          setActivePlaylist,
          customPlaylist,
          setCustomPlaylist,
          draftPlaylist,
          setDraftPlaylist,
          draftPlaylistMeta,
          setDraftPlaylistMeta,
          activeTrack,
          playTrack,
          audioRef,
          currentTime,
          setCurrentTime,
          openAppModal,
          closeAppModal,
          openDraftPlaylistModal,
          closeDraftPlaylistModal,
          user,
          setUser,
          isInputFocused,
          handleInputFocus,
          handleInputBlur
        }} />
      </main>
      <Footer />
      <Player
        activePlaylist={activePlaylist}
        activeTrack={activeTrack}
        setActiveTrack={setActiveTrack}
        audioRef={audioRef}
        setCurrentTime={setCurrentTime}
        customPlaylist={customPlaylist}
        isInputFocused={isInputFocused}
      />
      <AppModal
        isOpen={isAppModalOpen}
        onRequestClose={closeAppModal}
        modalContent={appModalContent}
      />
      <DraftPlaylistModal
        isOpen={isDraftPlaylistModalOpen}
        onRequestClose={closeDraftPlaylistModal}
        draftPlaylist={draftPlaylist}
        setDraftPlaylist={setDraftPlaylist}
        draftPlaylistMeta={draftPlaylistMeta}
        setDraftPlaylistMeta={setDraftPlaylistMeta}
        handleInputFocus={handleInputFocus}
        handleInputBlur={handleInputBlur}
      />
    </>
  );
};

export default Layout;
