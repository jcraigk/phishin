import React, { lazy } from "react";
import { authFetch } from "../helpers/utils";

// Lazy load components
const ApiDocs = lazy(() => import("../pages/ApiDocs"));
const ContactInfo = lazy(() => import("../pages/ContactInfo"));
const CoverArtInspector = lazy(() => import("../CoverArtInspector"));
const DraftPlaylist = lazy(() => import("../DraftPlaylist"));
const DynamicRoute = lazy(() => import("../routes/DynamicRoute"));
const Eras = lazy(() => import('../Eras'));
const ErrorPage = lazy(() => import("../pages/ErrorPage"));
const Faq = lazy(() => import("../pages/Faq"));
const Layout = lazy(() => import("../layout/Layout"));
const Login = lazy(() => import("../pages/Login"));
const MapSearch = lazy(() => import("../MapSearch"));
const MissingContentReport = lazy(() => import("../MissingContentReport"));
const MyShows = lazy(() => import("../MyShows"));
const MyTracks = lazy(() => import("../MyTracks"));
const Playlist = lazy(() => import("../Playlist"));
const PlaylistIndex = lazy(() => import("../PlaylistIndex"));
const PrivacyPolicy = lazy(() => import("../pages/PrivacyPolicy"));
const RequestPasswordReset = lazy(() => import("../pages/RequestPasswordReset"));
const ResetPassword = lazy(() => import("../pages/ResetPassword"));
const Search = lazy(() => import("../Search"));
const Settings = lazy(() => import("../pages/Settings"));
const Signup = lazy(() => import("../pages/Signup"));
const SongIndex = lazy(() => import("../SongIndex"));
const SongTracks = lazy(() => import("../SongTracks"));
const TagIndex = lazy(() => import("../TagIndex"));
const TaginProject = lazy(() => import("../pages/TaginProject"));
const TagShows = lazy(() => import("../TagShows"));
const TagTracks = lazy(() => import("../TagTracks"));
const TermsOfService = lazy(() => import("../pages/TermsOfService"));
const TodayShows = lazy(() => import("../TodayShows"));
const TopShows = lazy(() => import("../TopShows"));
const TopTracks = lazy(() => import("../TopTracks"));
const VenueIndex = lazy(() => import("../VenueIndex"));
const VenueShows = lazy(() => import("../VenueShows"));

// Loaders
import { coverArtInspectorLoader } from "../CoverArtInspector";
import { dynamicLoader } from "../routes/DynamicRoute";
import { erasLoader } from '../Eras';
import { missingContentLoader } from "../MissingContentReport";
import { myShowsLoader } from "../MyShows";
import { myTracksLoader } from "../MyTracks";
import { playlistIndexLoader } from "../PlaylistIndex";
import { playlistLoader } from "../Playlist";
import { songIndexLoader } from "../SongIndex";
import { songTracksLoader } from "../SongTracks";
import { tagIndexLoader } from "../TagIndex";
import { tagShowsLoader } from "../TagShows";
import { tagTracksLoader } from "../TagTracks";
import { todayShowsLoader } from "../TodayShows";
import { topShowsLoader } from "../TopShows";
import { topTracksLoader } from "../TopTracks";
import { venueIndexLoader } from "../VenueIndex";
import { venueShowsLoader } from "../VenueShows";

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
        path: "/settings",
        element: <Settings />,
      },
      // Unlisted pages
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
