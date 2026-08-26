module.exports = (request, response) => {
  const token = process.env.MAPBOX_ACCESS_TOKEN || '';

  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');

  if (!token.startsWith('pk.')) {
    response.status(503).json({
      configured: false,
      error: 'MAPBOX_ACCESS_TOKEN is not configured',
    });
    return;
  }

  response.status(200).json({
    configured: true,
    token,
  });
};
