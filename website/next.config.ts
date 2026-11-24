import type { NextConfig } from "next";

// When the site is hosted in a sub-folder (GitHub Pages project sites are), the deploy workflow sets this to "/voicey-website".
// Locally it stays empty, so `npm run dev` still runs at the root.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

const nextConfig: NextConfig = {
  output: "export", // build plain HTML, CSS and JS that any static host can serve
  basePath,
  trailingSlash: true,
  images: { unoptimized: true }, // there is no image server on a static host
};

export default nextConfig;
