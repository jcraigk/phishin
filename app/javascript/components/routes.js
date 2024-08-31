import React from "react";
import { createBrowserRouter } from "react-router-dom";

import Layout from "./Layout";
import Eras from "./Eras";
import Show from "./Show";
import YearRange from "./YearRange";

import ApiDocs from "./pages/ApiDocs";
import ContactUs from "./pages/ContactUs";
import ErrorNotice from "./pages/ErrorNotice";
import Faq from "./pages/Faq";
import PrivacyPolicy from "./pages/PrivacyPolicy";
import TaginProject from "./pages/TaginProject";
import TermsOfService from "./pages/TermsOfService";

const router = createBrowserRouter([
  {
    path: "/",
    element: <Layout appName="Phishin" />,
    errorElement: <ErrorNotice />,
    children: [
      {
        path: "/",
        element: <Eras />,
      },
      // Static pages
      {
        path: "api-docs",
        element: <ApiDocs />,
      },
      {
        path: "contact-us",
        element: <ContactUs />,
      },
      {
        path: "faq",
        element: <Faq />,
      },
      {
        path: "privacy",
        element: <PrivacyPolicy />,
      },
      {
        path: "tagin-project",
        element: <TaginProject />,
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
      //   path: "playlists",
      //   element: <Playlists />,
      // },
      // {
      //   path: "playlists",
      //   element: <Tags />,
      // },
      // {
      //   path: "today",
      //   element: <Today />,
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
