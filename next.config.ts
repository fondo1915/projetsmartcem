import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Cache Components (PPR expérimental) désactivé pour la Phase 1 :
  // comportement standard et prévisible, réévaluation possible en Phase 20.
  cacheComponents: false,
};

export default nextConfig;