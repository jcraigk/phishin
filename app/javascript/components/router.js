import React from "react";
import { createBrowserRouter } from "react-router-dom";

import DynamicRoute from "./DynamicRoute";
import Eras from "./Eras";
import Layout from "./Layout";
import MapView from "./MapView";
import MyShows from "./MyShows";
import MyTracks from "./MyTracks";
import Search from "./pages/Search";
import SongIndex from "./SongIndex";
import SongTracks from "./SongTracks";
import TagIndex from "./TagIndex";
import TagShows from "./TagShows";
import TagTracks from "./TagTracks";
import TodayShows from "./TodayShows";
import TopShows from "./TopShows";
import TopTracks from "./TopTracks";
import VenueIndex from "./VenueIndex";
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

const router = (props) =>
  createBrowserRouter([
    {
      path: "/",
      element: (<Layout user={props.user} onLogout={props.handleLogout} />),
      errorElement: <ErrorPage />,
      children: [
        // Root
        {
          path: "/",
          element: <Eras eras={props.eras} />
        },
        // Auth pages
        {
          path: "/login",
          element: <Login oauth_providers={props.oauth_providers} onLogin={props.handleLogin}  />
        },
        {
          path: "/signup",
          element: <Signup oauth_providers={props.oauth_providers} onSignup={props.handleLogin} />
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
          element: <ApiDocs base_url={props.base_url} />
        },
        {
          path: "/contact-info",
          element: <ContactInfo contact_email={props.contact_email} />
        },
        {
          path: "/faq",
          element: <Faq contact_email={props.contact_email} />
        },
        {
          path: "/privacy",
          element: <PrivacyPolicy />
        },
        {
          path: "/tagin-project",
          element: <TaginProject base_url={props.base_url} />
        },
        {
          path: "/terms",
          element: <TermsOfService />
        },
        // Content pages
        {
          path: "/venues",
          element: <VenueIndex />,
        },
        {
          path: "/venues/:venue_slug",
          element: <VenueShows />,
        },
        {
          path: "/songs",
          element: <SongIndex />,
        },
        {
          path: "/tags",
          element: <TagIndex />,
        },
        {
          path: "/show_tags/:tag_slug",
          element: <TagShows />,
        },
        {
          path: "/track_tags/:tag_slug",
          element: <TagTracks />,
        },
        {
          path: "/songs/:song_slug",
          element: <SongTracks />,
        },
        {
          path: "/map",
          element: <MapView mapbox_token={props.mapbox_token} />,
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
        //   path: "/play/:playlist_slug",
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
          path: ":route_path",
          element: <DynamicRoute />
        },
      ],
    },
  ]);

export default router;
