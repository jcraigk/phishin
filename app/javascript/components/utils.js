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
  return dateString?.replace(/-/g, ".");
};
export const formatDateMed = (dateString) => {
  const [year, month, day] = dateString.split("-").map(Number);
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  const formattedDate = `${monthNames[month - 1]} ${day}, ${year}`;
  return formattedDate;
};

export const formatDateLong = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
  });
};

export const toggleLike = async ({ id, type, isLiked }) => {
  const url = `/api/v2/likes?likable_type=${type}&likable_id=${id}`;
  const method = isLiked ? "DELETE" : "POST";
  let token = null;

  if (typeof window !== "undefined" && window.localStorage) {
    token = localStorage.getItem("jwt");
  }

  try {
    const response = await fetch(url, {
      method,
      headers: { "X-Auth-Token": token },
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

export const authFetch = async (url, options = {}) => {
  let token = null;

  if (typeof window !== "undefined" && window.localStorage) {
    token = localStorage.getItem("jwt");
  }

  const headers = {
    ...options.headers,
    ...(token ? { "X-Auth-Token": token } : {}),
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  return response;
};

export const parseTimeParam = (t) => {
  if (!t) return null;
  if (t.includes(":")) {
    const [minutes, seconds] = t.split(":").map(Number);
    return minutes * 60 + seconds;
  }
  return Number(t);
};
