/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",

  redirects: async () => {
    return [
      {
        source: "/",
        destination: "/server",
        permanent: false,
      },
    ];
  },
};

export default nextConfig;
