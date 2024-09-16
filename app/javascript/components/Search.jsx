import React, { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import SearchResults from "./SearchResults";
import LayoutWrapper from "./LayoutWrapper"; // For sidebar layout
import { authFetch } from "./utils";

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
      <div className="field">
        <label className="label">Search</label>
        <div className="control">
          <input
            className="input"
            type="text"
            value={term}
            onChange={(e) => setTerm(e.target.value)}
            placeholder="Enter search term"
            onKeyDown={handleKeyDown} // Capture "Enter" key press
          />
        </div>
      </div>

      <div className="field">
        <label className="label">Scope</label>
        <div className="control">
          <div className="select">
            <select value={scope} onChange={(e) => setScope(e.target.value)}>
              <option value="all">All</option>
              <option value="shows">Shows</option>
              <option value="songs">Songs</option>
              <option value="tags">Tags</option>
              <option value="tours">Tours</option>
              <option value="venues">Venues</option>
            </select>
          </div>
        </div>
      </div>

      <div className="control">
        <button className="button" onClick={handleSearch}>
          Search
        </button>
      </div>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {results && <SearchResults results={results} term={submittedTerm} />}
    </LayoutWrapper>
  );
};

export default Search;
