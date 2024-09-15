import React from "react";

import DynamicRoute, { dynamicLoader } from "./DynamicRoute";
import Eras, { erasLoader } from './Eras';
import EraShows, { eraShowsLoader } from './EraShows';
import Layout from "./Layout";
import MapView from "./MapView";
import MyShows from "./MyShows";
import MyTracks from "./MyTracks";
import Search from "./pages/Search";
import SongIndex, { songIndexLoader } from "./SongIndex";
import SongTracks from "./SongTracks";
import TagIndex from "./TagIndex";
import TagShows from "./TagShows";
import TagTracks from "./TagTracks";
import TodayShows from "./TodayShows";
import TopShows from "./TopShows";
import TopTracks from "./TopTracks";
import VenueIndex, { venueIndexLoader } from "./VenueIndex";
import VenueShows from "./VenueShows";

import ApiDocs from "./pages/ApiDocs";
import ContactInfo from "./pages/ContactInfo";
import ErrorPage from "./pages/ErrorPage";
import Faq from "./pages/Faq";
import Login from "./pages/Login";
import PrivacyPolicy from "./pages/PrivacyPolicy";
import RequestPasswordReset from "./pages/RequestPasswordReset";
import ResetPassword from "./pages/ResetPassword";
import Signup from "./pages/Signup";
import TaginProject from "./pages/TaginProject";
import TermsOfService from "./pages/TermsOfService";

const routes = (props) => [
  {
    path: "/",
    element: (<Layout user={props.user} onLogout={props.handleLogout} />),
    errorElement: <ErrorPage />,
    children: [
      // Root
      {
        path: "/",
        element: <Eras />,
        loader: erasLoader,
      },
      // Auth pages
      {
        path: "/login",
        element: <Login oauthProviders={props.oauth_providers} onLogin={props.handleLogin}  />
      },
      {
        path: "/signup",
        element: <Signup handleLogin={props.handleLogin} />
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
        element: <ApiDocs baseUrl={props.base_url} />
      },
      {
        path: "/contact-info",
        element: <ContactInfo contactEmail={props.contact_email} />
      },
      {
        path: "/faq",
        element: <Faq contactEmail={props.contact_email} />
      },
      {
        path: "/privacy",
        element: <PrivacyPolicy />
      },
      {
        path: "/tagin-project",
        element: <TaginProject baseUrl={props.base_url} />
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
      },
      {
        path: "/songs",
        element: <SongIndex />,
        loader: songIndexLoader,
      },
      {
        path: "/tags",
        element: <TagIndex />,
      },
      {
        path: "/show_tags/:tagSlug",
        element: <TagShows />,
      },
      {
        path: "/track_tags/:tagSlug",
        element: <TagTracks />,
      },
      {
        path: "/songs/:songSlug",
        element: <SongTracks />,
      },
      {
        path: "/map",
        element: <MapView mapboxToken={props.mapbox_token} />,
      },
      {
        path: "/top-shows",
        element: <TopShows user={props.user} />,
      },
      {
        path: "/top-tracks",
        element: <TopTracks user={props.user} />,
      },
      {
        path: "/my-shows",
        element: <MyShows />,
      },
      {
        path: "/my-tracks",
        element: <MyTracks />,
      },
      // {
      //   path: "/playlist",
      //   element: <Playlist />,
      // },
      // {
      //   path: "/playlists",
      //   element: <Playlists />,
      // },
      // {
      //   path: "/play/:playlistSlug",
      //   element: <Playlist />,
      // },
      {
        path: "/today",
        element: <TodayShows />,
      },
      {
        path: "/search",
        element: <Search />,
      },
      {
        path: ":routePath",
        element: <DynamicRoute />,
        loader: dynamicLoader,
      },
    ],
  },
];

export default routes;
