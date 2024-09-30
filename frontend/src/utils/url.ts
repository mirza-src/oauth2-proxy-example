import { headers } from "next/headers";

export const currentOrigin = () => {
  if (typeof window !== "undefined") {
    return window.location.origin;
  }

  const headerList = headers();
  let host = headerList.get("x-forwarded-host")?.split(",")[0];
  if (!host) {
    host = headerList.get("host")?.split(",")[0];
  }

  if (!host) {
    throw new Error("No host header found");
  }

  const proto = headerList.get("x-forwarded-proto")?.split(",")[0] || "https";
  return `${proto}://${host}`;
};
