// Places each label as close to its segment's center as it can without
// overlapping its neighbors. Labels that collide are merged into a group and
// the group is centered on its members, so a run of short songs spreads its
// labels above and below the run rather than pushing them all downward.
const placeGroup = (members, centers, heights) => {
  let size = 0;
  let idealTopSum = 0;
  members.forEach((index) => {
    idealTopSum += centers[index] - heights[index] / 2 - size;
    size += heights[index];
  });
  return { members, size, top: Math.max(0, idealTopSum / members.length) };
};

export const layoutLabels = (centers, heights) => {
  const groups = [];
  centers.forEach((_, index) => {
    let group = placeGroup([index], centers, heights);
    while (groups.length > 0) {
      const previous = groups[groups.length - 1];
      if (previous.top + previous.size <= group.top) break;
      groups.pop();
      group = placeGroup([...previous.members, ...group.members], centers, heights);
    }
    groups.push(group);
  });

  return groups.flatMap(({ members, top }) => {
    let next = top;
    return members.map((index) => {
      const position = next;
      next += heights[index];
      return position;
    });
  });
};
