import React, { useRef, useState } from "react";
import { Outlet, useNavigate, useNavigation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import Loader from "../controls/Loader";
import Player from "../controls/Player";
import AppModal from "../modals/AppModal";
import DraftPlaylistModal from "../modals/DraftPlaylistModal";
import { useFeedback } from "../controls/FeedbackContext";

const initialDraftPlaylistMeta = {
  id: null,
  name: "",
  slug: "",
  description: "",
  published: false,
};

const Layout = ({ user, setUser }) => {
  const navigation = useNavigation();
  const navigate = useNavigate();
  const [isAppModalOpen, setIsAppModalOpen] = useState(false);
  const [appModalContent, setAppModalContent] = useState(null);
  const [isDraftPlaylistModalOpen, setIsDraftPlaylistModalOpen] = useState(false);
  const [activePlaylist, setActivePlaylist] = useState([]);
  const [customPlaylist, setCustomPlaylist] = useState(null);
  const [draftPlaylist, setDraftPlaylist] = useState([]);
  const [draftPlaylistMeta, setDraftPlaylistMeta] = useState(initialDraftPlaylistMeta);
  const [activeTrack, setActiveTrack] = useState(null);
  const audioRef = useRef(null);
  const { setNotice } = useFeedback();

  const handleLogin = (userData, message) => {
    if (typeof window !== "undefined") {
      localStorage.setItem("jwt", userData.jwt);
      localStorage.setItem("username", userData.username);
      localStorage.setItem("usernameUpdatedAt", userData.usernameUpdatedAt);
      localStorage.setItem("email", userData.email);

      const redirectPath = localStorage.getItem("redirectAfterLogin") || "/";
      localStorage.removeItem("redirectAfterLogin");
      navigate(redirectPath);
      setNotice(message);
    }
    setUser(userData);
  };

  const handleLogout = () => {
    if (typeof window !== "undefined") {
      localStorage.removeItem("jwt");
      localStorage.removeItem("username");
      localStorage.removeItem("usernameUpdatedAt");
      localStorage.removeItem("email");
    }
    setUser(null);
    setNotice("Logged out successfully");
  };

  const resetDraftPlaylist = () => {
    setDraftPlaylist([]);
    setDraftPlaylistMeta(initialDraftPlaylistMeta);
  };

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
      <Navbar user={user} handleLogout={handleLogout} />
      <main className={activeTrack ? 'with-player' : ''}>
        <Outlet context={{
          user,
          handleLogin,
          handleLogout,
          activePlaylist,
          setActivePlaylist,
          customPlaylist,
          setCustomPlaylist,
          draftPlaylist,
          setDraftPlaylist,
          draftPlaylistMeta,
          setDraftPlaylistMeta,
          resetDraftPlaylist,
          activeTrack,
          playTrack,
          audioRef,
          openAppModal,
          closeAppModal,
          openDraftPlaylistModal,
          closeDraftPlaylistModal,
        }} />
      </main>
      <Footer />
      <Player
        activePlaylist={activePlaylist}
        activeTrack={activeTrack}
        setActiveTrack={setActiveTrack}
        audioRef={audioRef}
        customPlaylist={customPlaylist}
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
        resetDraftPlaylist={resetDraftPlaylist}
      />
    </>
  );
};

export default Layout;
