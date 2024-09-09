import React, { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import SearchResults from "./SearchResults";
import PageWrapper from "./PageWrapper";

const Search = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [term, setTerm] = useState(searchParams.get("term") || "");
  const [scope, setScope] = useState(searchParams.get("scope") || "all");
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [submittedTerm, setSubmittedTerm] = useState(searchParams.get("term") || ""); // Keeps track of the term for the title

  useEffect(() => {
    setTerm(searchParams.get("term") || "");
    setScope(searchParams.get("scope") || "all");

    // Automatically trigger search if term is present in the URL
    if (searchParams.get("term")) {
      performSearch(searchParams.get("term"), searchParams.get("scope") || "all");
    }
  }, [searchParams]);

  const performSearch = async (searchTerm, searchScope) => {
    setLoading(true);
    setError(null);
    setResults(null); // Clear old results while loading

    try {
      const response = await fetch(`/api/v2/search/${searchTerm}?scope=${searchScope}`);
      if (!response.ok) throw new Error("Search failed");
      const data = await response.json();
      setResults(data);
      setSubmittedTerm(searchTerm); // Set the submitted term after successful search
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!term) return; // Don't search with an empty term
    performSearch(term, scope);
    // Update URL with search parameters after search button is clicked
    setSearchParams({ term, scope });
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearch();
    }
  };

  return (
    <PageWrapper>
      <div className="search-component">
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
          <button className="button is-primary" onClick={handleSearch}>
            Search
          </button>
        </div>

        {loading && <p>Loading...</p>}
        {error && <p className="has-text-danger">{error}</p>}

        {!loading && results && <SearchResults results={results} term={submittedTerm} />}
      </div>
    </PageWrapper>
  );
};

export default Search;
