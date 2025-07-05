import React, { useRef, useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import logo from "../../images/logo-full.png";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faQuestionCircle, faBook, faTags, faAddressBook, faUserShield, faFileContract, faCalendar, faMicrophone, faMapMarkerAlt, faAward, faCalendarDay, faSearch, faAngleDown, faRecordVinyl, faGuitar, faChevronDown, faCircleXmark, faRightToBracket, faGear, faClipboardList, faListCheck, faListOl, faDiceFive, faLandmark, faRss, faSquareCheck, faSquare } from "@fortawesome/free-solid-svg-icons";
import { useAudioFilter } from "../contexts/AudioFilterContext";

const Navbar = ({ user, handleLogout }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isInfoDropdownOpen, setIsInfoDropdownOpen] = useState(false);
  const [isContentDropdownOpen, setIsContentDropdownOpen] = useState(false);
  const [isUserDropdownOpen, setIsUserDropdownOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const navigate = useNavigate();
  const infoDropdownRef = useRef(null);
  const contentDropdownRef = useRef(null);
  const userDropdownRef = useRef(null);
  const { showMissingAudio, toggleShowMissingAudio } = useAudioFilter();

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (infoDropdownRef.current && !infoDropdownRef.current.contains(event.target)) {
        setIsInfoDropdownOpen(false);
      }
      if (contentDropdownRef.current && !contentDropdownRef.current.contains(event.target)) {
        setIsContentDropdownOpen(false);
      }
      if (userDropdownRef.current && !userDropdownRef.current.contains(event.target)) {
        setIsUserDropdownOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [infoDropdownRef, contentDropdownRef, userDropdownRef]);

  const closeMenus = () => {
    setIsMenuOpen(false);
    setIsInfoDropdownOpen(false);
    setIsContentDropdownOpen(false);
    setIsUserDropdownOpen(false);
  };

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    if (searchTerm) {
      navigate(`/search?term=${searchTerm}`);
      closeMenus();
    }
  };

  const staticLinks = [
    { path: "/faq", label: "FAQ", icon: faQuestionCircle },
    { path: "/api-docs", label: "API Docs", icon: faBook },
    { path: "/rss", label: "RSS Feed", icon: faRss },
    { path: "/tagin-project", label: "Tagin' Project", icon: faTags },
    { path: "/contact-info", label: "Contact Info", icon: faAddressBook },
    { path: "/privacy", label: "Privacy Policy", icon: faUserShield },
    { path: "/terms", label: "Terms of Service", icon: faFileContract },
  ];

  const browseLinks = [
    { path: "/", label: "Years", icon: faCalendar },
    { path: "/today", label: "Today", icon: faCalendarDay },
    { path: "/venues", label: "Venues", icon: faLandmark },
    { path: "/songs", label: "Songs", icon: faMicrophone },
    { path: "/tags", label: "Tags", icon: faTags },
    { path: "/map", label: "Map", icon: faMapMarkerAlt },
    { path: "/playlists", label: "Playlists", icon: faClipboardList },
  ];

  const topLinks = [
    { path: "/top-shows", label: "Top 46 Shows", icon: faAward },
    { path: "/top-tracks", label: "Top 46 Tracks", icon: faAward },
  ];

  const userLinks = [
    { path: "/my-shows", label: "My Shows", icon: faGuitar },
    { path: "/my-tracks", label: "My Tracks", icon: faRecordVinyl },
    { path: "/draft-playlist", label: "Draft Playlist", icon: faListCheck },
    { path: "/playlists?filter=mine", label: "My Playlists", icon: faListOl },
  ];

  const combinedLinks = [
    ...browseLinks.map(link => ({ ...link, type: 'link' })),
    { type: 'divider' },
    ...topLinks.map(link => ({ ...link, type: 'link' })),
  ];

  const AudioFilterToggle = () => (
    <div
      className={`dropdown-item audio-filter-toggle ${showMissingAudio ? 'active' : ''}`}
      onClick={toggleShowMissingAudio}
    >
      <FontAwesomeIcon
        icon={showMissingAudio ? faSquareCheck : faSquare}
        className="icon"
      />
      Include missing audio
    </div>
  );

  return (
    <>
      <div id="navbar-background">
        <nav className="navbar" role="navigation">
          <div className="navbar-brand">

            <div className="site-logo">
              <Link to="/" onClick={closeMenus}>
                <img src={logo}  alt="Site logo" />
              </Link>
            </div>

            <a
              role="button"
              className={`navbar-burger ${isMenuOpen ? "is-active" : ""}`}
              data-target="navbar"
              onClick={() => setIsMenuOpen(!isMenuOpen)}
            >
              <span></span>
              <span></span>
              <span></span>
              <span></span>
            </a>
          </div>

          <div id="navbar" className={`navbar-menu ${isMenuOpen ? "is-active" : ""}`}>
            <div className="navbar-start">

              <div className={`dropdown navbar-item ${isInfoDropdownOpen ? "is-active" : ""}`} ref={infoDropdownRef}>
                <div className="dropdown-trigger">
                  <button className="button" onClick={() => setIsInfoDropdownOpen(!isInfoDropdownOpen)}>
                    <span className="navbar-dropdown-label">INFO</span>
                    <span className="icon">
                      <FontAwesomeIcon icon={faAngleDown} />
                    </span>
                  </button>
                </div>
                <div className="dropdown-menu" role="menu">
                  <div className="dropdown-content">
                    {staticLinks.map((item, index) => (
                      <Link
                        key={item.path}
                        to={item.path}
                        className="dropdown-item"
                        onClick={() => closeMenus()}
                      >
                        <FontAwesomeIcon icon={item.icon} className="icon" />
                        {item.label}
                      </Link>
                    ))}
                  </div>
                </div>
              </div>

              <div className={`dropdown navbar-item ${isContentDropdownOpen ? "is-active" : ""}`} ref={contentDropdownRef}>
                <div className="dropdown-trigger">
                  <button className="button" onClick={() => setIsContentDropdownOpen(!isContentDropdownOpen)}>
                    <span className="navbar-dropdown-label">CONTENT</span>
                    <span className="icon">
                      <FontAwesomeIcon icon={faAngleDown} />
                    </span>
                  </button>
                </div>
                <div className="dropdown-menu" role="menu">
                  <div className="dropdown-content">
                    <AudioFilterToggle />
                    <hr className="dropdown-divider" />
                    {combinedLinks.map((item, index) => (
                      item.type === 'link' ? (
                        <Link
                          key={item.path}
                          to={item.path}
                          className="dropdown-item"
                          onClick={() => closeMenus()}
                        >
                          <FontAwesomeIcon icon={item.icon} className="icon" />
                          {item.label}
                        </Link>
                      ) : (
                        <hr key={`divider-${index}`} className="dropdown-divider" />
                      )
                    ))}
                    <hr className="dropdown-divider" />
                    <a
                      className="dropdown-item"
                      onClick={async () => {
                        closeMenus();
                        try {
                          const response = await fetch('/api/v2/shows/random');
                          if (!response.ok) throw response;
                          const show = await response.json();
                          navigate(`/${show.date}`);
                        } catch (error) {
                          console.error('Error fetching random show:', error);
                        }
                      }}
                    >
                      <FontAwesomeIcon icon={faDiceFive} className="icon" />
                      Random Show
                    </a>
                  </div>
                </div>
              </div>

              <div className="navbar-item">
                <form onSubmit={handleSearchSubmit} className="control has-icons-left">
                  <input
                    id="nav-search"
                    className="input search-term"
                    type="text"
                    placeholder="SEARCH"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    autoCapitalize="off"
                  />
                  <span className="icon is-left">
                    <FontAwesomeIcon icon={faSearch} />
                  </span>
                </form>
              </div>
            </div>

            <div className="navbar-end">
              <div className="navbar-item">
                {(user === null || user === "anonymous") && (
                  <div className="navbar-item">
                    <Link
                      to="/login"
                      className="button login-btn"
                      onClick={() => {
                        if (typeof window !== "undefined") {
                          localStorage.setItem("redirectAfterLogin", location.pathname);
                        }
                        closeMenus();
                      }}
                    >
                      <div className="icon">
                        <FontAwesomeIcon icon={faRightToBracket} />
                      </div>
                      LOGIN
                    </Link>
                  </div>
                )}

                {(user !== null && user !== "anonymous") && (
                  <div className={`dropdown navbar-item user-dropdown ${isUserDropdownOpen ? "is-active" : ""}`} ref={userDropdownRef}>
                    <div className="dropdown-trigger">
                      <button className="button" onClick={() => setIsUserDropdownOpen(!isUserDropdownOpen)}>
                        <span>{user.username}</span>
                        <span className="icon">
                          <FontAwesomeIcon icon={faChevronDown} />
                        </span>
                      </button>
                    </div>
                    <div className="dropdown-menu" role="menu">
                      <div className="dropdown-content">
                        {userLinks.map((item, index) => (
                          <Link
                            key={item.path}
                            to={item.path}
                            className="dropdown-item"
                            onClick={closeMenus}
                          >
                            <FontAwesomeIcon icon={item.icon} className="icon" />
                            {item.label}
                          </Link>
                        ))}
                        <hr className="dropdown-divider" />
                        <Link to="/settings" className="dropdown-item" onClick={closeMenus}>
                          <FontAwesomeIcon icon={faGear} className="icon" />
                          Settings
                        </Link>
                        <a id="logout" href="#logout" className="dropdown-item" onClick={(e) => {
                          e.preventDefault();
                          closeMenus();
                          handleLogout();
                        }}>
                          <FontAwesomeIcon icon={faCircleXmark} className="icon" />
                          Logout
                        </a>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </nav>
      </div>
    </>
  );
};

export default Navbar;
