import React, { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "react-router";
import { authFetch } from "./helpers/utils";
import SearchResults from "./SearchResults";
import LayoutWrapper from "./layout/LayoutWrapper";
import Loader from "./controls/Loader";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";
import { useServerFilteredData } from "./hooks/useServerFilteredData";

const Search = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [term, setTerm] = useState(searchParams.get("term") || "");
  const [scope, setScope] = useState(searchParams.get("scope") || "all");
  const [submittedTerm, setSubmittedTerm] = useState("");
  const [isSearching, setIsSearching] = useState(false);
  const [results, setResults] = useState(null);

  const performSearchWithFilter = useCallback(async (audioStatusFilter) => {
    if (!submittedTerm) return null;

    setIsSearching(true);
    const response = await authFetch(`/api/v2/search/${encodeURIComponent(submittedTerm)}?scope=${scope}&audio_status=${audioStatusFilter}`);
    const data = await response.json();
    setIsSearching(false);
    return data;
  }, [submittedTerm, scope]);

    const { data: filteredResults, isRefetching } = useServerFilteredData(results, performSearchWithFilter, [submittedTerm, scope]);

  useEffect(() => {
    const urlTerm = searchParams.get("term") || "";
    const urlScope = searchParams.get("scope") || "all";

    setTerm(urlTerm);
    setScope(urlScope);

    if (urlTerm && urlTerm !== submittedTerm) {
      performSearch(urlTerm, urlScope);
    }
  }, [searchParams]);

  const performSearch = async (searchTerm, searchScope) => {
    setSubmittedTerm(searchTerm);
    setScope(searchScope);

    setIsSearching(true);
    try {
      const response = await authFetch(`/api/v2/search/${encodeURIComponent(searchTerm)}?scope=${searchScope}&audio_status=complete_or_partial`);
      const data = await response.json();
      setResults(data);
    } catch (error) {
      console.error('Search error:', error);
    } finally {
      setIsSearching(false);
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

      <div className="display-phone-only">
        <p className="has-text-weight-bold is-size-4">Search Results</p>
      </div>

      <div className="hidden-phone">
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
          <FontAwesomeIcon icon={faSearch} className="mr-1" />
          Search
        </button>
      </div>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {isRefetching || isSearching ? (
        <Loader />
      ) : (
        (filteredResults || results) && <SearchResults results={filteredResults || results} term={submittedTerm} />
      )}
    </LayoutWrapper>
  );
};

export default Search;
