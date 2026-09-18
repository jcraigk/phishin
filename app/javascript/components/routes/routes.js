import React from "react";

import DynamicRoute, { dynamicLoader } from "../routes/DynamicRoute";
import Eras, { erasLoader } from "../Eras";
import Layout from "../layout/Layout";
import ErrorPage from "../pages/ErrorPage";

const lazyRoute = (importer, loaderName) => async () => {
  const page = await importer();
  const route = { Component: page.default };
  if (loaderName) route.loader = page[loaderName];
  return route;
};

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
        lazy: lazyRoute(() => import("../MissingContentReport"), "missingContentLoader"),
      },
      {
        path: "/login",
        lazy: lazyRoute(() => import("../pages/Login")),
      },
      {
        path: "/signup",
        lazy: lazyRoute(() => import("../pages/Signup")),
      },
      {
        path: "/request-password-reset",
        lazy: lazyRoute(() => import("../pages/RequestPasswordReset")),
      },
      {
        path: "/reset-password/:token",
        lazy: lazyRoute(() => import("../pages/ResetPassword")),
      },
      // Static pages
      {
        path: "/api-docs",
        lazy: lazyRoute(() => import("../pages/ApiDocs")),
      },
      {
        path: "/contact-info",
        lazy: lazyRoute(() => import("../pages/ContactInfo")),
      },
      {
        path: "/faq",
        lazy: lazyRoute(() => import("../pages/Faq")),
      },
      {
        path: "/privacy",
        lazy: lazyRoute(() => import("../pages/PrivacyPolicy")),
      },
      {
        path: "/terms",
        lazy: lazyRoute(() => import("../pages/TermsOfService")),
      },
      // Content pages
      {
        path: "/venues",
        lazy: lazyRoute(() => import("../VenueIndex"), "venueIndexLoader"),
      },
      {
        path: "/venues/:venueSlug",
        lazy: lazyRoute(() => import("../VenueShows"), "venueShowsLoader"),
      },
      {
        path: "/songs",
        lazy: lazyRoute(() => import("../SongIndex"), "songIndexLoader"),
      },
      {
        path: "/tags",
        lazy: lazyRoute(() => import("../TagIndex"), "tagIndexLoader"),
      },
      {
        path: "/show-tags/:tagSlug",
        lazy: lazyRoute(() => import("../TagShows"), "tagShowsLoader"),
      },
      {
        path: "/track-tags/:tagSlug",
        lazy: lazyRoute(() => import("../TagTracks"), "tagTracksLoader"),
      },
      {
        path: "/songs/:songSlug",
        lazy: lazyRoute(() => import("../SongTracks"), "songTracksLoader"),
      },
      {
        path: "/map",
        lazy: lazyRoute(() => import("../MapSearch")),
      },
      {
        path: "/top-shows",
        lazy: lazyRoute(() => import("../TopShows"), "topShowsLoader"),
      },
      {
        path: "/top-tracks",
        lazy: lazyRoute(() => import("../TopTracks"), "topTracksLoader"),
      },
      {
        path: "/my-shows",
        lazy: lazyRoute(() => import("../MyShows"), "myShowsLoader"),
      },
      {
        path: "/my-tracks",
        lazy: lazyRoute(() => import("../MyTracks"), "myTracksLoader"),
      },
      {
        path: "/draft-playlist",
        lazy: lazyRoute(() => import("../DraftPlaylist")),
      },
      {
        path: "/playlists",
        lazy: lazyRoute(() => import("../PlaylistIndex"), "playlistIndexLoader"),
      },
      {
        path: "/play/:playlistSlug",
        lazy: lazyRoute(() => import("../Playlist"), "playlistLoader"),
      },
      {
        path: "/today",
        lazy: lazyRoute(() => import("../TodayShows"), "todayShowsLoader"),
      },
      {
        path: "/search",
        lazy: lazyRoute(() => import("../Search")),
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
        lazy: lazyRoute(() => import("../pages/Settings")),
      },
      {
        path: "/cover-art",
        lazy: lazyRoute(() => import("../CoverArtInspector"), "coverArtInspectorLoader"),
      },
      {
        path: "/admin",
        loader: async () => {
          const deny = () => {
            throw new Response("Not Found", { status: 404 });
          };
          if (typeof window === "undefined" || !localStorage.getItem("jwt")) deny();
          if (window.phishinAdminVerified) return null;
          const { adminGet } = await import("../admin/adminApi");
          try {
            await adminGet("/jobs?limit=1");
          } catch (e) {
            if (e.status === 401 || e.status === 403) {
              localStorage.setItem("admin", "false");
              deny();
            }
          }
          window.phishinAdminVerified = true;
          return null;
        },
        lazy: async () => {
          const { default: Component } = await import("../admin/AdminLayout");
          return { Component };
        },
        children: [
          {
            index: true,
            lazy: async () => {
              const { default: Component } = await import("../admin/AdminDashboard");
              return { Component };
            },
          },
          {
            path: "shows",
            lazy: async () => {
              const { default: Component } = await import("../admin/AdminShows");
              return { Component };
            },
          },
          {
            path: "import",
            lazy: async () => {
              const { default: Component } = await import("../admin/AdminImport");
              return { Component };
            },
          },
          {
            path: "shows/:date",
            lazy: async () => {
              const { default: Component } = await import("../admin/AdminShowEditor");
              return { Component };
            },
          },
          {
            path: "traffic",
            lazy: async () => {
              const { default: Component } = await import("../admin/AdminTraffic");
              return { Component };
            },
          },
        ],
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
