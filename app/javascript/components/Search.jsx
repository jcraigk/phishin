import React, { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import { authFetch } from "./utils";
import SearchResults from "./SearchResults";
import LayoutWrapper from "./LayoutWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const Search = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [term, setTerm] = useState(searchParams.get("term") || "");
  const [scope, setScope] = useState(searchParams.get("scope") || "all");
  const [results, setResults] = useState(null);
  const [submittedTerm, setSubmittedTerm] = useState(searchParams.get("term") || "");

  useEffect(() => {
    setTerm(searchParams.get("term") || "");
    setScope(searchParams.get("scope") || "all");

    if (searchParams.get("term")) {
      performSearch(searchParams.get("term"), searchParams.get("scope") || "all");
    }
  }, [searchParams]);

  const performSearch = async (searchTerm, searchScope) => {
    setResults(null);

    try {
      const response = await authFetch(`/api/v2/search/${searchTerm}?scope=${searchScope}`);
      const data = await response.json();
      setResults(data);
      setSubmittedTerm(searchTerm);
    } catch (error) {
      throw new Response("Error performing search", { status: 500 });
    }
  };

  const handleSearch = async () => {
    if (!term) return;
    performSearch(term, scope);
    setSearchParams({ term, scope });
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearch();
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <label className="label">Search Term</label>
      <input
        className="input search-term-form"
        type="text"
        value={term}
        onChange={(e) => setTerm(e.target.value)}
        placeholder="Enter search term"
        onKeyDown={handleKeyDown}
        autoCapitalize="off"
      />

      <label className="label scope-label">Scope</label>
      <div className="select">
        <select value={scope} onChange={(e) => setScope(e.target.value)}>
          <option value="all">All</option>
          <option value="playlists">Playlists</option>
          <option value="shows">Shows</option>
          <option value="songs">Songs</option>
          <option value="tags">Tags</option>
          <option value="tracks">Tracks</option>
          <option value="venues">Venues</option>
        </select>
      </div>

      <button className="button ml-3" onClick={handleSearch}>
        <div className="icon mr-1">
          <FontAwesomeIcon icon={faSearch} />
        </div>
        Search
      </button>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {results && <SearchResults results={results} term={submittedTerm} />}
    </LayoutWrapper>
  );
};

export default Search;
