export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let pathname = url.pathname;
    if (pathname === "/") pathname = "/index.html";
    try {
      const asset = await env.__STATIC_CONTENT.get(pathname.slice(1), "arrayBuffer");
      if (!asset) return new Response("Not found", { status: 404 });
      // Basic content type detection
      let contentType = "application/octet-stream";
      if (pathname.endsWith(".html")) contentType = "text/html";
      else if (pathname.endsWith(".js")) contentType = "application/javascript";
      else if (pathname.endsWith(".css")) contentType = "text/css";
      else if (pathname.endsWith(".png")) contentType = "image/png";
      else if (pathname.endsWith(".jpg") || pathname.endsWith(".jpeg")) contentType = "image/jpeg";
      else if (pathname.endsWith(".svg")) contentType = "image/svg+xml";
      return new Response(asset, { headers: { "content-type": contentType } });
    } catch (e) {
      return new Response("Error serving asset", { status: 500 });
    }
  }
};
