import { useState } from "react";
import { useNavigate } from "react-router-dom";

export const paginationHelper = (initialPage, initialSortOption, initialPerPage) => {
  const navigate = useNavigate();

  const [currentPage, setCurrentPage] = useState(initialPage); // Use initialPage
  const [currentSortOption, setCurrentSortOption] = useState(initialSortOption); // Use initialSortOption
  const [tempPerPage, setTempPerPage] = useState(initialPerPage); // Use initialPerPage

  const handlePageClick = (data, firstChar = '') => {
    const selectedPage = data.selected + 1;
    setCurrentPage(selectedPage); // Update current page
    navigate(`?page=${selectedPage}&sort=${currentSortOption}&first_char=${firstChar}&per_page=${tempPerPage}`);
  };

  const handleSortChange = (event, firstChar = '') => {
    const newSortOption = event.target.value;
    setCurrentSortOption(newSortOption); // Update current sort option
    navigate(`?page=1&sort=${newSortOption}&first_char=${firstChar}&per_page=${tempPerPage}`);
  };

  const handlePerPageInputChange = (e) => {
    setTempPerPage(e.target.value);
  };

  const submitPerPage = (firstChar = '') => {
    if (tempPerPage && !isNaN(tempPerPage) && tempPerPage > 0) {
      navigate(`?page=1&sort=${currentSortOption}&first_char=${firstChar}&per_page=${tempPerPage}`);
    }
  };

  const handlePerPageBlurOrEnter = (e, firstChar = '') => {
    if (e.type === "blur" || (e.type === "keydown" && e.key === "Enter")) {
      e.preventDefault();
      submitPerPage(firstChar);
      e.target.blur();
    }
  };

  return {
    currentPage,
    currentSortOption,
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  };
};
