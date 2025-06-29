/** @type {import('next').NextConfig} */
const nextConfig = {
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  env: {
    NEXT_PUBLIC_LIQUIDATION_AGENT_API_URL: process.env.LIQUIDATION_AGENT_API_URL || 'http://localhost:3001',
  },
}

export default nextConfig