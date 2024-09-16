import React from "react";
import PageWrapper from "./PageWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExternalLinkAlt } from "@fortawesome/free-solid-svg-icons";

const ApiDocs = ({ baseUrl }) => {
  return (
    <PageWrapper>
      <h1 className="title">API Documentation</h1>

      <h2 className="title">API Keys</h2>
      <p className="font-semibold mb-8">
        API keys can be requested via email, see the <a href="/contact-info" className="has-text-link is-underlined">contact page</a>.
      </p>

      <hr />

      <h2 className="title">API v2</h2>
      <a
        href={`https://petstore.swagger.io/?url=${baseUrl}/api/v2/swagger_doc`}
        target="_blank"
        className="button"
      >
        API v2 Documentation
        <FontAwesomeIcon icon={faExternalLinkAlt} className="ml-2" />
      </a>

      <hr />

      <h2 className="title">API v1</h2>

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
        All endpoints can be reached by using the full address of <span className="has-text-weight-bold">{baseUrl}/api/v1</span> followed by one of these routes:
      </p>

      <div className="mb-6">
        <span className="api-command">GET /eras</span>
        <span className="api-doc">Returns all Eras and the Years that belong to each</span>
      </div>

      <h3 className="title">Examples</h3>
      <p>[1] Requesting "the song with ID of 40":</p>
      <span className="api-command mb-2">
        GET {baseUrl}/api/v1/songs/40.json
      </span>
      <p>will result in this response:</p>
      <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto mb-4">
        {`{ "success": true, "total_entries": 1, "total_pages": 1, "page": 1, "data": { "id": 40, "title": "Any Colour You Like", "alias": null, "tracks_count": 1, "slug": "any-colour-you-like", "updated_at": "2012-08-25T15:04:00Z", "tracks": [ { "id": 17963, "title": "Any Colour You Like", "duration": 211696, "show_id": 904, "show_date": "1998-11-02", "set": "2", "position": 20, "likes_count": 0, "slug": "any-colour-you-like", "mp3": "https://phish.in/audio/000/017/963/17963.mp3" } ] } }`}
      </pre>

      <p>[2] Requesting "the 3 most recent shows":</p>
      <span className="api-command mb-2">
        GET {baseUrl}/api/v1/shows.json?per_page=3&page=1&sort_attr=date&sort_dir=desc
      </span>
      <p>will result in a response that looks like this:</p>
      <pre className="box bg-gray-100 p-4 rounded-lg overflow-x-auto">
        {`{ "success": true, "total_entries": 1467, "total_pages": 489, "page": 1, "data": [ /* Shows data */ ] }`}
      </pre>
    </PageWrapper>
  );
};

export default ApiDocs;
