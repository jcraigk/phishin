import { useState } from "react";
import { useNavigate } from "react-router-dom";

export const paginationHelper = (initialPage, initialSortOption, initialPerPage, firstChar = "", filter = "all") => {
  const navigate = useNavigate();

  const [currentPage, setCurrentPage] = useState(initialPage);
  const [currentSortOption, setCurrentSortOption] = useState(initialSortOption);
  const [tempPerPage, setTempPerPage] = useState(initialPerPage);

  const handlePageClick = (data) => {
    const selectedPage = data.selected + 1;
    setCurrentPage(selectedPage);
    navigate(`?page=${selectedPage}&sort=${currentSortOption}&first_char=${firstChar}&per_page=${tempPerPage}&filter=${filter}`);
  };

  const handleSortChange = (event) => {
    const newSortOption = event.target.value;
    setCurrentSortOption(newSortOption);
    navigate(`?page=1&sort=${newSortOption}&first_char=${firstChar}&per_page=${tempPerPage}&filter=${filter}`);
  };

  const handlePerPageInputChange = (e) => {
    setTempPerPage(e.target.value);
  };

  const submitPerPage = () => {
    if (tempPerPage && !isNaN(tempPerPage) && tempPerPage > 0) {
      navigate(`?page=1&sort=${currentSortOption}&first_char=${firstChar}&per_page=${tempPerPage}&filter=${filter}`);
    }
  };

  const handlePerPageBlurOrEnter = (e) => {
    if (e.type === "blur" || (e.type === "keydown" && e.key === "Enter")) {
      e.preventDefault();
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
