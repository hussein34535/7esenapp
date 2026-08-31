export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const asset = await env.ASSETS.fetch(url);
    if (asset.status !== 404) return asset;
    return env.ASSETS.fetch(new URL('/', url));
  },
};
