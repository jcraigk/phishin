import React from "react";
import { useLocation } from "react-router";
import PageWrapper from "./PageWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExternalLinkAlt } from "@fortawesome/free-solid-svg-icons";
import EmailButton from "./EmailButton";

const ApiDocs = () => {
  const location = useLocation();

  return (
    <PageWrapper>
      <h1 className="title">API Documentation</h1>
      <p>Phish.in provides programmatic access to content for free via a RESTful JSON API. Version 2 is the latest stable version and is recommended. Additionally, an MCP (Model Context Protocol) server is available for AI assistant integration.</p>

      <hr className="mt-6 mb-6" />

      <h2 className="title">API v2</h2>
      <h3 className="subtitle">Recommended Version</h3>
      <p>Version 2 of the API was released September 2024 and is the recommended version. Follow the link below for interactive documentation in Swagger. Browse the <a href="https://github.com/jcraigk/phishin/tree/main/app/api/api_v2" target="_blank">Grape API source</a> on GitHub. Phish.in (this website) uses v2 of the API so you can also look at the <a href="https://github.com/jcraigk/phishin/tree/main/app/javascript/components/" target="_blank">React source</a> on GitHub to see working examples.</p>

      <p>No API key is required to access v2 of the API.</p>

      <a
        href="https://petstore.swagger.io/?url=https%3A%2F%2Fphish.in/api/v2/swagger_doc"
        target="_blank"
        className="button"
      >
        API v2 Documentation
        <FontAwesomeIcon icon={faExternalLinkAlt} className="ml-2" />
      </a>

      <hr className="mt-6 mb-6" />

      <h2 className="title">MCP Server</h2>
      <h3 className="subtitle">AI Integration</h3>
      <p>
        Phish.in exposes data through a{" "}
        <a href="https://modelcontextprotocol.io/" target="_blank">Model Context Protocol (MCP)</a>{" "}
        server, enabling AI assistants and other MCP clients to interact with the platform using natural language.
        The server is read-only and does not require authentication.
      </p>

      <h4 className="title is-5 mt-4">Endpoint</h4>
      <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto mb-4">
        POST https://phish.in/mcp
      </pre>

      <h4 className="title is-5">Available Tools</h4>
      <ul className="list-disc list-inside mb-4">
        <li><strong>search</strong> - Search across shows, songs, venues, tours, tags, and playlists</li>
        <li><strong>list_shows</strong> - List shows with optional setlist details, filtered by year, tour, venue, or date</li>
        <li><strong>list_songs</strong> - List songs with performance statistics</li>
        <li><strong>list_venues</strong> - List venues with geographic filtering</li>
        <li><strong>list_tours</strong> - List tours with date ranges and show counts</li>
        <li><strong>list_years</strong> - List years/periods with show counts and era designations</li>
        <li><strong>get_song</strong> - Get detailed song information including performances and lyrics</li>
        <li><strong>get_venue</strong> - Get venue details with show history</li>
        <li><strong>get_tour</strong> - Get tour details with associated shows</li>
        <li><strong>get_playlist</strong> - Get public playlist details</li>
        <li><strong>stats</strong> - Statistical analysis: gaps/bustouts, transitions, set positions, predictions, streaks, geographic patterns, co-occurrence, song frequency</li>
      </ul>

      <hr className="mt-6 mb-6" />

      <details className="mb-6">
        <summary className="title is-4 cursor-pointer">Legacy API (v1)</summary>
        <div className="mt-4">
          <p>
            Version 1 of the API was released in 2013 and is considered legacy. It is still available for use, but it is recommended to use the newer version. You can browse the <a href="https://github.com/jcraigk/phishin/tree/main/app/controllers/api/v1" target="_blank">source on GitHub</a>. Below is documentation for the legacy API.
          </p>
          <p className="notification is-warning">
            <strong>Note:</strong> API v1 returns only shows and tracks with available audio recordings. For access to the complete catalog of known setlists (including shows without circulating recordings), use API v2.
          </p>

          <p className="font-semibold mb-8">
            API keys can be requested via email:{" "}
          </p>
          <EmailButton />
          <br />
          <br />

          <div className="box">
            <h3 className="title">Requests</h3>
            <p className="mb-4">
              All requests must be in the form of
              <span className="api-inline">HTTP GET</span> and must include the
              <span className="api-inline">Accept: application/json</span> header as well as a bearer auth header:
              <span className="api-inline">Authorization: Bearer &lt;your_api_key&gt;</span>
            </p>

            <h3 className="title">Responses</h3>
            <p>
              Responses will include the header <span className="api-inline">Content-Type: application/json</span> and should be parsed as JSON.
            </p>
            <p>Responses to successful requests look like this:</p>
            <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto mb-4">
              {`{ "success": true, "total_entries": #, "total_pages": #, "page": #, "data": [response content] }`}
            </pre>
            <p>Responses to failed calls look like this:</p>
            <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto mb-4">
              {`{ success: false, message: "Something went wrong!" }`}
            </pre>

            <h3 className="title">Parameters</h3>
            <p>Most routes accept the following optional parameters:</p>
            <ul className="list-disc list-inside mb-4">
              <li>
                <span className="api-inline">sort_attr</span>: Which attribute to sort on (Ex: "date", "name")
              </li>
              <li>
                <span className="api-inline">sort_dir</span>: Which direction to sort in (asc|desc)
              </li>
              <li>
                <span className="api-inline">per_page</span>: How many results to list per page (default: 20)
              </li>
              <li>
                <span className="api-inline">page</span>: Which page of results to display (default: 1)
              </li>
            </ul>

            <p>A few routes also accept the following optional parameters:</p>
            <ul className="list-disc list-inside mb-4">
              <li>
                <span className="api-inline">tag</span>: [/tracks and /shows] Return only results that have the
                specified tag slug (Example: /shows?tag=sbd)
              </li>
            </ul>

            <h3 className="title">Endpoints</h3>
            <p>
              All endpoints can be reached by using the full address of <span className="has-text-weight-bold">{location.pathname}/api/v1</span> followed by one of these routes:
            </p>

            <div className="mb-6">
              <span className="api-command">GET /eras</span>
              <span className="api-doc">Returns all Eras and the Years that belong to each</span>
            </div>

            <h3 className="title">Examples</h3>
            <p>[1] Requesting "the song with ID of 40":</p>
            <span className="api-command mb-2">
              GET https://phish.in/api/v1/songs/40.json
            </span>
            <p>will result in this response:</p>
            <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto mb-4">
              {`{ "success": true, "total_entries": 1, "total_pages": 1, "page": 1, "data": { "id": 40, "title": "Any Colour You Like", "alias": null, "tracks_count": 1, "slug": "any-colour-you-like", "updated_at": "2012-08-25T15:04:00Z", "tracks": [ { "id": 17963, "title": "Any Colour You Like", "duration": 211696, "show_id": 904, "show_date": "1998-11-02", "set": "2", "position": 20, "likes_count": 0, "slug": "any-colour-you-like", "mp3": "https://phish.in/audio/000/017/963/17963.mp3" } ] } }`}
            </pre>

            <p>[2] Requesting "the 3 most recent shows":</p>
            <span className="api-command mb-2">
              GET https://phish.in/api/v1/shows.json?per_page=3&page=1&sort_attr=date&sort_dir=desc
            </span>
            <p>will result in a response that looks like this:</p>
            <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto">
              {`{ "success": true, "total_entries": 1467, "total_pages": 489, "page": 1, "data": [ /* Shows data */ ] }`}
            </pre>
          </div>
        </div>
      </details>
    </PageWrapper>
  );
};

export default ApiDocs;
