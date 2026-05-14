import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(__dirname, '../..');

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@gastrovoyage/shared'],
  experimental: {
    typedRoutes: true,
    // Help Next trace into the monorepo when building.
    outputFileTracingRoot: workspaceRoot,
  },
};

export default nextConfig;
