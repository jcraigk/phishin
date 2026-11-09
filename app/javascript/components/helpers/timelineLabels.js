// Places each label as close to its segment's center as it can without
// overlapping its neighbors. Labels that collide are merged into a group and
// the group is centered on its members, so a run of short songs spreads its
// labels to both sides of the run rather than pushing them all one way.
const placeGroup = (members, centers, sizes) => {
  let size = 0;
  let idealStartSum = 0;
  members.forEach((index) => {
    idealStartSum += centers[index] - sizes[index] / 2 - size;
    size += sizes[index];
  });
  return { members, size, start: Math.max(0, idealStartSum / members.length) };
};

export const layoutLabels = (centers, sizes) => {
  const groups = [];
  centers.forEach((_, index) => {
    let group = placeGroup([index], centers, sizes);
    while (groups.length > 0) {
      const previous = groups[groups.length - 1];
      if (previous.start + previous.size <= group.start) break;
      groups.pop();
      group = placeGroup([...previous.members, ...group.members], centers, sizes);
    }
    groups.push(group);
  });

  return groups.flatMap(({ members, start }) => {
    let next = start;
    return members.map((index) => {
      const position = next;
      next += sizes[index];
      return position;
    });
  });
};

// Moves labels left where needed so none passes its limit, keeping at least
// `spacing` between neighbors.
export const pullLabelsLeft = (positions, spacing, limits) => {
  const pulled = [...positions];
  for (let index = pulled.length - 1; index >= 0; index--) {
    let limit = limits[index];
    if (index < pulled.length - 1) limit = Math.min(limit, pulled[index + 1] - spacing);
    pulled[index] = Math.min(pulled[index], limit);
  }
  return pulled;
};
