import React from "react";
import { createBrowserRouter } from "react-router-dom";

import Layout from "./Layout";
import Eras from "./Eras";
import Show from "./Show";
import YearRange from "./YearRange";

import ApiDocs from "./pages/ApiDocs";
import ContactInfo from "./pages/ContactInfo";
import ErrorPage from "./pages/ErrorPage";
import Faq from "./pages/Faq";
import PrivacyPolicy from "./pages/PrivacyPolicy";
import TaginProject from "./pages/TaginProject";
import TermsOfService from "./pages/TermsOfService";
import RequestPasswordReset from "./pages/RequestPasswordReset";
import ResetPassword from "./pages/ResetPassword";
import Login from "./pages/Login";
import Signup from "./pages/Signup";

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
          element: <Eras eras={props.eras} />,
        },
        // Auth pages
        {
          path: "login",
          element: <Login oauth_providers={props.oauth_providers} onLogin={props.handleLogin}  />
        },
        {
          path: "signup",
          element: <Signup oauth_providers={props.oauth_providers} onSignup={props.handleLogin} />
        },
        {
        path: "/request-password-reset",
          element: <RequestPasswordReset />,
        },
        {
          path: "/reset-password/:token",
          element: <ResetPassword />,
        },
        // Static pages
        {
          path: "api-docs",
          element: <ApiDocs base_url={props.base_url} />,
        },
        {
          path: "contact-info",
          element: <ContactInfo contact_email={props.contact_email} />,
        },
        {
          path: "faq",
          element: <Faq contact_email={props.contact_email} />,
        },
        {
          path: "privacy",
          element: <PrivacyPolicy />,
        },
        {
          path: "tagin-project",
          element: <TaginProject base_url={props.base_url} />,
        },
        {
          path: "terms",
          element: <TermsOfService />,
        },
        // Index pages
        // {
        //   path: "years",
        //   element: <Eras />,
        // },
        // {
        //   path: "venues",
        //   element: <Venues />,
        // },
        // {
        //   path: "songs",
        //   element: <Songs />,
        // },
        // {
        //   path: "map",
        //   element: <Map />,
        // },
        // {
        //   path: "top-shows",
        //   element: <TopShows />,
        // },
        // {
        //   path: "top-tracks",
        //   element: <TopTracks />,
        // },
        // {
        //   path: "playlist",
        //   element: <Playlist />,
        // },
        // {
        //   path: "playlists",
        //   element: <Playlists />,
        // },
        // {
        //   path: "play/:playlist_slug",
        //   element: <Playlist />,
        // },
        // {
        //   path: "today",
        //   element: <Today />,
        // },
        // {
        //   path: "search",
        //   element: <Search />,
        // },
        // User content pages
        // {
        //   path: "my-shows",
        //   element: <MyShows />,
        // },
        // {
        //   path: "my-tracks",
        //   element: <MyTracks />,
        // },
        // Content slugs
        {
          path: ":date(\\d{4}-\\d{2}-\\d{2})",
          element: <Show />,
        },
        {
          path: ":yearRange(\\d{4}(-\\d{4})?)",
          element: <YearRange />,
        },
        // Catch-all route for arbitrary slugs
        // {
        //   path: ":slug",
        //   element: <SongOrVenue />,
        // },
      ],
    },
  ]);

export default router;
