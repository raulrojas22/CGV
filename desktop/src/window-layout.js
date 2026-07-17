function finiteDimension(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
}

function computeWindowBounds(workArea = {}) {
  const availableWidth = finiteDimension(workArea.width, 1440);
  const availableHeight = finiteDimension(workArea.height, 900);
  const minWidth = Math.min(1040, availableWidth);
  const minHeight = Math.min(620, availableHeight);
  const width = Math.min(1480, Math.max(minWidth, Math.floor(availableWidth * 0.92)));
  const height = Math.min(960, Math.max(minHeight, Math.floor(availableHeight * 0.92)));

  return {
    width: Math.min(width, availableWidth),
    height: Math.min(height, availableHeight),
    minWidth,
    minHeight
  };
}

module.exports = { computeWindowBounds };
