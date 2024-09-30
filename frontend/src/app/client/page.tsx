"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

export default function Page() {
  const [data, setData] = useState("");
  const [userinfo, setUserinfo] = useState("");

  useEffect(() => {
    (async () => {
      // No need for any tokens as it will forwarded based on the browser's cookies by oauth2-proxy
      const apiRes = await fetch(`${window.location.origin}/api/`);
      const data = await apiRes.text();
      setData(data);

      const keycloakRes = await fetch(
        // /auth does not add Authorization header, /iam does
        `${window.location.origin}/iam/realms/application/protocol/openid-connect/userinfo`
      );
      const userinfo = await keycloakRes.text();
      setUserinfo(userinfo);
    })();
  }, []);

  return (
    <div className="grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20 font-[family-name:var(--font-geist-sans)]">
      <main className="flex flex-col gap-8 row-start-2 items-center sm:items-start">
        <Image
          className="dark:invert"
          src="https://nextjs.org/icons/next.svg"
          alt="Next.js logo"
          width={180}
          height={38}
          priority
        />
        <div>
          <h1 className="text-3xl font-bold">Client Component</h1>
          <a href="/server" className="text-blue-500">
            Go to server component
          </a>
        </div>
        <p>
          Response from API: <code>{data}</code>
        </p>
        <p>
          Userinfo from Keycloak: <code>{userinfo}</code>
        </p>
      </main>
    </div>
  );
}
