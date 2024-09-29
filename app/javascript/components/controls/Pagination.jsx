import React from "react";
import ReactPaginate from "react-paginate";

const Pagination = ({ totalPages, handlePageClick, currentPage, perPage, handlePerPageInputChange, handlePerPageBlurOrEnter }) => {
  return (
    <div className="pagination-container">
      <ReactPaginate
        previousLabel={"Previous"}
        nextLabel={"Next"}
        breakLabel={"..."}
        breakClassName={"break-me"}
        pageCount={totalPages}
        marginPagesDisplayed={1}
        pageRangeDisplayed={1}
        onPageChange={handlePageClick}
        containerClassName={"pagination"}
        activeClassName={"active"}
        forcePage={currentPage}
      />
      <div className="per-page-input hidden-mobile">
        <label htmlFor="per-page">Per page:</label>
        <input
          type="number"
          id="per-page"
          value={perPage}
          onChange={handlePerPageInputChange}
          onBlur={handlePerPageBlurOrEnter}
          onKeyDown={handlePerPageBlurOrEnter}
          min="1"
          className="input per-page"
        />
      </div>
    </div>
  );
};

export default Pagination;
