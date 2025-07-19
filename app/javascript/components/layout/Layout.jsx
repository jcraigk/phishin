import React, { useState, useEffect } from "react";
import { Outlet, useNavigate, useNavigation, ScrollRestoration } from "react-router-dom";
import Navbar from "./Navbar";
import Loader from "../controls/Loader";
import Player from "../controls/Player";
import AppModal from "../modals/AppModal";
import DraftPlaylistModal from "../modals/DraftPlaylistModal";
import { useFeedback } from "../contexts/FeedbackContext";
import { AudioFilterProvider, useAudioFilter } from "../contexts/AudioFilterContext";

const initialDraftPlaylistMeta = {
  id: null,
  name: "",
  slug: "",
  description: "",
  published: false,
};

const LayoutContent = ({ props, navigate }) => {
  const navigation = useNavigation();
  const [user, setUser] = useState(null);
  const [isAppModalOpen, setIsAppModalOpen] = useState(false);
  const [appModalContent, setAppModalContent] = useState(null);
  const [isDraftPlaylistModalOpen, setIsDraftPlaylistModalOpen] = useState(false);
  const [activePlaylist, setActivePlaylist] = useState([]);
  const [activeTrack, setActiveTrack] = useState(null);
  const [customPlaylist, setCustomPlaylist] = useState(null);
  const [draftPlaylist, setDraftPlaylist] = useState([]);
  const [draftPlaylistMeta, setDraftPlaylistMeta] = useState(initialDraftPlaylistMeta);
  const [isDraftPlaylistSaved, setIsDraftPlaylistSaved] = useState(false);
  const [viewMode, setViewMode] = useState("grid");
  const [sortOption, setSortOption] = useState("desc");
  const [shouldAutoplay, setShouldAutoplay] = useState(false);
  const { setNotice, setAlert } = useFeedback();
  const { isFilterLoading } = useAudioFilter();

  useEffect(() => {
    // OAuth failure
    if (props.alert) {
      setAlert(props.alert);
    // OAuth success
    } else if (props.jwt) {
      handleLogin({
        jwt: props.jwt,
        username: props.username,
        usernameUpdatedAt: props.usernameUpdatedAt,
        email: props.email,
      }, "Google login successful");
    } else {
      let jwt = "";
      let username = "";
      let email = "";
      let usernameUpdatedAt = "";

      if (typeof window !== "undefined") {
        jwt = localStorage.getItem("jwt");
        username = localStorage.getItem("username");
        usernameUpdatedAt = localStorage.getItem("usernameUpdatedAt");
        email = localStorage.getItem("email");
      }

      if (jwt && username && email) {
        setUser({ jwt, username, usernameUpdatedAt, email });
      } else {
        setUser("anonymous");
      }
    }
  }, []);

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
    navigate("/");
    setUser("anonymous");
    setNotice("Logged out successfully");
  };

  const resetDraftPlaylist = () => {
    setDraftPlaylist([]);
    setDraftPlaylistMeta(initialDraftPlaylistMeta);
  };

  const playTrack = (playlist, track, fromUrlParam = false) => {
    setActivePlaylist(playlist);
    setActiveTrack(track);
    setShouldAutoplay(!fromUrlParam);
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
      <ScrollRestoration />
      {(navigation.state === "loading" || isFilterLoading) && <Loader />}
      <Navbar user={user} handleLogout={handleLogout} />
      <main className={activeTrack ? "with-player" : ""}>
        <Outlet
          context={{
            ...props,
            user,
            setUser,
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
            isDraftPlaylistSaved,
            setIsDraftPlaylistSaved,
            activeTrack,
            playTrack,
            openAppModal,
            closeAppModal,
            openDraftPlaylistModal,
            closeDraftPlaylistModal,
            viewMode,
            setViewMode,
            sortOption,
            setSortOption
          }}
        />
      </main>
      <Player
        activePlaylist={activePlaylist}
        activeTrack={activeTrack}
        setActiveTrack={setActiveTrack}
        customPlaylist={customPlaylist}
        openAppModal={openAppModal}
        shouldAutoplay={shouldAutoplay}
        setShouldAutoplay={setShouldAutoplay}
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
        isDraftPlaylistSaved={isDraftPlaylistSaved}
        setIsDraftPlaylistSaved={setIsDraftPlaylistSaved}
        resetDraftPlaylist={resetDraftPlaylist}
      />
    </>
  );
};

const Layout = ({ props }) => {
  const navigate = useNavigate();

  return (
    <AudioFilterProvider navigate={navigate}>
      <LayoutContent props={props} navigate={navigate} />
    </AudioFilterProvider>
  );
};

export default Layout;
