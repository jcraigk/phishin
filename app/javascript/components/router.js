import React from "react";
import { createBrowserRouter } from "react-router-dom";

import DynamicRoute from "./DynamicRoute";
import Eras from "./Eras";
import Layout from "./Layout";
import Venues from "./Venues";
import Songs from "./Songs";
import Shows from "./Shows";

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
      element: (
        <Layout
          appName={props.app_name}
          user={props.user}
          onLogout={props.handleLogout}
        />
      ),
      errorElement: <ErrorPage />,
      children: [
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
        // Index pages
        {
          path: "/venues",
          element: <Venues />,
        },
        {
          path: "/venues/:venue_slug",
          element: <Shows />,
        },
        {
          path: "/songs",
          element: <Songs />,
        },
        // {
        //   path: "/songs/:song_slug",
        //   element: <Tracks />,
        // },
        // {
        //   path: "/map",
        //   element: <Map />,
        // },
        // {
        //   path: "/top-shows",
        //   element: <TopShows />,
        // },
        // {
        //   path: "/top-tracks",
        //   element: <TopTracks />,
        // },
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
        // {
        //   path: "/today",
        //   element: <Today />,
        // },
        // {
        //   path: "/search",
        //   element: <Search />,
        // },
        // User content pages
        // {
        //   path: "/my-shows",
        //   element: <MyShows />,
        // },
        // {
        //   path: "/my-tracks",
        //   element: <MyTracks />,
        // }
        // Content slugs
        {
          path: ":route_path",
          element: <DynamicRoute />
        },
      ],
    },
  ]);

export default router;
