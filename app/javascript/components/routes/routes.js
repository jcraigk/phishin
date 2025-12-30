import React from "react";

// Content pages with sidebar
import DraftPlaylist from "../DraftPlaylist";
import DynamicRoute, { dynamicLoader } from "../routes/DynamicRoute";
import Eras, { erasLoader } from '../Eras';
import Layout from "../layout/Layout";
import MapSearch from "../MapSearch";
import MissingContentReport, { missingContentLoader } from "../MissingContentReport";
import MyShows, { myShowsLoader } from "../MyShows";
import MyTracks, { myTracksLoader } from "../MyTracks";
import Playlist, { playlistLoader } from "../Playlist";
import PlaylistIndex, { playlistIndexLoader } from "../PlaylistIndex";
import Search from "../Search";
import SongIndex, { songIndexLoader } from "../SongIndex";
import SongTracks, { songTracksLoader } from "../SongTracks";
import TagIndex, { tagIndexLoader } from "../TagIndex";
import TagShows, { tagShowsLoader } from "../TagShows";
import TagTracks, { tagTracksLoader } from "../TagTracks";
import TodayShows, { todayShowsLoader } from "../TodayShows";
import TopShows, { topShowsLoader } from "../TopShows";
import TopTracks, { topTracksLoader } from "../TopTracks";
import VenueIndex, { venueIndexLoader } from "../VenueIndex";
import VenueShows, { venueShowsLoader } from "../VenueShows";
import CoverArtInspector, { coverArtInspectorLoader } from "../CoverArtInspector";

// Simple pages with no sidebar
import ApiDocs from "../pages/ApiDocs";
import ContactInfo from "../pages/ContactInfo";
import ErrorPage from "../pages/ErrorPage";
import Faq from "../pages/Faq";
import Login from "../pages/Login";
import PrivacyPolicy from "../pages/PrivacyPolicy";
import RequestPasswordReset from "../pages/RequestPasswordReset";
import ResetPassword from "../pages/ResetPassword";
import Signup from "../pages/Signup";
import TaginProject from "../pages/TaginProject";
import TermsOfService from "../pages/TermsOfService";
import Settings from "../pages/Settings";

const routes = (props) => [
  {
    path: "/",
    element: (<Layout props={props} />),
    errorElement: <ErrorPage />,
    children: [
      {
        path: "/",
        element: <Eras />,
        loader: erasLoader,
      },
      {
        path: "/missing-content",
        element: <MissingContentReport />,
        loader: missingContentLoader,
      },
      {
        path: "/login",
        element: <Login />
      },
      {
        path: "/signup",
        element: <Signup />
      },
      {
      path: "/request-password-reset",
        element: <RequestPasswordReset />
      },
      {
        path: "/reset-password/:token",
        element: <ResetPassword />
      },
      // Static pages
      {
        path: "/api-docs",
        element: <ApiDocs />
      },
      {
        path: "/contact-info",
        element: <ContactInfo />
      },
      {
        path: "/faq",
        element: <Faq />
      },
      {
        path: "/privacy",
        element: <PrivacyPolicy />
      },
      {
        path: "/tagin-project",
        element: <TaginProject />
      },
      {
        path: "/terms",
        element: <TermsOfService />
      },
      // Content pages
      {
        path: "/venues",
        element: <VenueIndex />,
        loader: venueIndexLoader,
      },
      {
        path: "/venues/:venueSlug",
        element: <VenueShows />,
        loader: venueShowsLoader,
      },
      {
        path: "/songs",
        element: <SongIndex />,
        loader: songIndexLoader,
      },
      {
        path: "/tags",
        element: <TagIndex />,
        loader: tagIndexLoader,
      },
      {
        path: "/show-tags/:tagSlug",
        element: <TagShows />,
        loader: tagShowsLoader,
      },
      {
        path: "/track-tags/:tagSlug",
        element: <TagTracks />,
        loader: tagTracksLoader,
      },
      {
        path: "/songs/:songSlug",
        element: <SongTracks />,
        loader: songTracksLoader,
      },
      {
        path: "/map",
        element: <MapSearch />,
      },
      {
        path: "/top-shows",
        element: <TopShows />,
        loader: topShowsLoader,
      },
      {
        path: "/top-tracks",
        element: <TopTracks />,
        loader: topTracksLoader,
      },
      {
        path: "/my-shows",
        element: <MyShows />,
        loader: myShowsLoader,
      },
      {
        path: "/my-tracks",
        element: <MyTracks />,
        loader: myTracksLoader,
      },
      {
        path: "/draft-playlist",
        element: <DraftPlaylist />,
      },
      {
        path: "/playlists",
        element: <PlaylistIndex />,
        loader: playlistIndexLoader,
      },
      {
        path: "/play/:playlistSlug",
        element: <Playlist />,
        loader: playlistLoader,
      },
      {
        path: "/today",
        element: <TodayShows />,
        loader: todayShowsLoader,
      },
      {
        path: "/search",
        element: <Search />,
      },
      {
        path: "/random",
        loader: async () => {
          const response = await fetch("/api/v2/shows/random");
          if (!response.ok) throw response;
          const show = await response.json();
          return new Response(null, {
            status: 302,
            headers: { Location: `/${show.date}` },
          });
        },
      },
      {
        path: "/settings",
        element: <Settings />,
      },
      {
        path: "/cover-art",
        element: <CoverArtInspector />,
        loader: coverArtInspectorLoader,
      },
      {
        path: "*",
        element: <DynamicRoute />,
        loader: dynamicLoader,
      },
    ],
  },
];

export default routes;
