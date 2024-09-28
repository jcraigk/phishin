import React from "react";
import ReactPaginate from "react-paginate";

const Pagination = ({ totalPages, handlePageClick, currentPage }) => {
  return (
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
  );
};

export default Pagination;
