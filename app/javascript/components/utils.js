export const formatNumber = (number, label = "") => {
  const formattedNumber = number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${formattedNumber} ${label}${number !== 1 && label ? "s" : ""}`;
};

export const formatDurationShow = (milliseconds) => {
  const totalMinutes = Math.floor(milliseconds / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  } else {
    return `${minutes}m`;
  }
};

export const formatDurationTrack = (milliseconds) => {
  const totalSeconds = Math.floor(milliseconds / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const formattedMinutes = hours > 0 ? minutes.toString().padStart(2, "0") : minutes.toString();
  const formattedSeconds = seconds.toString().padStart(2, "0");

  if (hours > 0) {
    return `${hours}:${formattedMinutes}:${formattedSeconds}`;
  } else {
    return `${formattedMinutes}:${formattedSeconds}`;
  }
};


export const formatDate = (dateString) => {
  return dateString.replace(/-/g, ".");
};

export const formatDateLong = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
};

export const toggleLike = async ({ id, type, isLiked, jwt }) => {
  const url = `/api/v2/likes?likable_type=${type}&likable_id=${id}`;
  const method = isLiked ? "DELETE" : "POST";

  try {
    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-Auth-Token": jwt,
      },
    });

    if (response.ok) {
      return { success: true, isLiked: !isLiked };
    } else {
      console.error("Failed to toggle like");
      return { success: false };
    }
  } catch (error) {
    console.error("Error toggling like:", error);
    return { success: false };
  }
};
