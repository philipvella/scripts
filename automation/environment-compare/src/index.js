// Simple Cloudflare Worker to serve static files from the deploy folder
export default {
  async fetch(request, env, ctx) {
    return await env.ASSETS.fetch(request);
  }
};

