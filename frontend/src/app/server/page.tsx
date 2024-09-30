import { currentOrigin } from "@/utils/url";
import { headers } from "next/headers";
import Image from "next/image";

export default async function Page() {
  const apiRes = await fetch(`${currentOrigin()}/api/`, {
    headers: {
      // Server-side calls need to forward cookies sent by the browser
      // HACK: Nextjs cookies().toString() returns a invlaid string (as it is url-encoded)
      cookie: headers().get("cookie") || "",
    },
  });
  const data = await apiRes.text();

  const keycloakRes = await fetch(
    // /auth does not add Authorization header, /iam does
    `${currentOrigin()}/iam/realms/application/protocol/openid-connect/userinfo`,
    {
      // Server-side calls can also forward authorization header sent by the browser
      headers: {
        authorization: headers().get("authorization") || "",
      },
    }
  );
  const userinfo = await keycloakRes.text();
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
          <h1 className="text-3xl font-bold">Server Component</h1>
          <a href="/client" className="text-blue-500">
            Go to client component
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
