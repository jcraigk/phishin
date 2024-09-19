import React, { useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";
import { toggleLike } from "./utils";
import { useFeedback } from "./FeedbackContext";

const LikeButton = ({ likable }) => {
  const { setAlert, setNotice } = useFeedback();
  const [likedByUser, setLikedByUser] = useState(likable.liked_by_user);
  const [likesCount, setLikesCount] = useState(likable.likes_count);

  const type = likable.date ? "Show" : "Track";

  const handleLikeToggle = async (e) => {
    e.stopPropagation();
    let jwt = null;

    if (typeof window !== "undefined") {
      jwt = localStorage.getItem("jwt");
      if (!jwt) {
        setAlert("Please login to save likes");
        return;
      }
    }

    const result = await toggleLike({
      id: likable.id,
      type, // Dynamically use the inferred type
      isLiked: likedByUser,
      jwt,
    });

    if (result.success) {
      setLikedByUser(result.isLiked);
      setLikesCount(result.isLiked ? likesCount + 1 : likesCount - 1);
      setNotice("Like saved");
    } else {
      setAlert("Like failed to save");
    }
  };

  return (
    <div className="like-wrapper">
      <FontAwesomeIcon
        icon={faHeart}
        className={`heart-icon ${likedByUser ? "liked" : ""}`}
        onClick={handleLikeToggle}
      />{" "}
      <span className="likes-count">
        {likesCount}
      </span>
    </div>
  );
};

export default LikeButton;
