import { QueryClient, QueryClientProvider, useQuery } from "@tanstack/react-query";
import { createMemoryHistory, createRouter, RouterProvider } from "@tanstack/react-router";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { MotionConfig } from "motion/react";
import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom/client";

import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import { Bootstrap } from "@/components/quick-launch";
import { I18nProvider } from "@/i18n";
import { getStartupOptions } from "@/lib/startup";
import { routeTree } from "@/route-tree.gen";
import { useThemeStore } from "@/stores/theme";

import "@/index.css";

const memoryHistory = createMemoryHistory({ initialEntries: ["/"] });

const router = createRouter({ routeTree, history: memoryHistory });

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      gcTime: 30 * 60 * 1000,
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

document.addEventListener("contextmenu", (e) => e.preventDefault());
document.addEventListener("dragstart", (e) => e.preventDefault());
document.addEventListener("drop", (e) => e.preventDefault());
document.addEventListener("dragover", (e) => e.preventDefault());

function Root() {
  const applyTheme = useThemeStore((state) => state.apply);

  useEffect(() => {
    applyTheme();
  }, [applyTheme]);

  const { data, isPending } = useQuery({
    queryKey: ["startup-options"],
    queryFn: getStartupOptions,
    staleTime: Infinity,
    gcTime: Infinity,
    retry: false,
  });
  
  const [warmRequest, setWarmRequest] = useState<{ uri: string | null } | null>(null);

  useEffect(() => {
    let disposed = false;
    const unlistenPromise = listen<{ uri: string | null }>("bootstrap-request", ({ payload }) => {
      if (!disposed) {
        setWarmRequest({ uri: payload.uri ?? null });
      }
    });
    return () => {
      disposed = true;
      void unlistenPromise.then((unlisten) => unlisten());
    };
  }, []);

  if (isPending) {
    return null;
  }

  if (warmRequest) {
    return <Bootstrap uri={warmRequest.uri} onExit={() => setWarmRequest(null)} />;
  }

  if (data?.bootstrap) {
    return (
      <Bootstrap
        uri={data.studioUri}
        onExit={() => {
          getCurrentWindow().close().catch(console.error);
        }}
      />
    );
  }

  return <RouterProvider router={router} />;
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <I18nProvider>
        <MotionConfig reducedMotion="user">
          <Root />
        </MotionConfig>
      </I18nProvider>
    </QueryClientProvider>
  </React.StrictMode>,
);
