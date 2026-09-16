import React, { useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import DraftPlaylistDetails from "./DraftPlaylistDetails";
import DraftTrackControls from "./DraftTrackControls";
import PlaylistBuilder from "./PlaylistBuilder";
import { useFeedback } from "./contexts/FeedbackContext";

const DraftPlaylist = () => {
  const { draftPlaylist, draftPlaylistMeta, user } = useOutletContext();
  const { setAlert } = useFeedback();
  const navigate = useNavigate();

  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must login to do that");
    }
  }, [navigate, user]);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="sidebar-title">Draft Playlist</h1>
      <DraftPlaylistDetails />
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{`${draftPlaylistMeta.name || "Draft Playlist"} - Phish.in`}</title>
      </Helmet>
      <div className="draft-page">
      <LayoutWrapper sidebarContent={sidebarContent}>
        <PlaylistBuilder />

        <div className="draft-track-list">
          {draftPlaylist.length === 0 ? (
            <div className="notification draft-empty">
              No tracks yet. Add some from the panel above, or from any show page.
            </div>
          ) : (
            <Tracks
              tracks={draftPlaylist}
              viewStyle="draft"
              numbering={true}
              omitSecondary={true}
              renderRowControls={(track, index) => (
                <DraftTrackControls track={track} index={index} />
              )}
            />
          )}
        </div>
      </LayoutWrapper>
      </div>
    </>
  );
};

export default DraftPlaylist;
