import { createRootRoute, Outlet, useRouterState } from "@tanstack/react-router";
import { motion } from "motion/react";
import { useEffect } from "react";

import { AppSidebar } from "@/components/app-sidebar";
import { Bootstrapper } from "@/components/bootstrapper";
import TitleBar from "@/components/title-bar";
import { useStudioAutoSetup } from "@/hooks/use-studio-auto-setup";
import { useThemeStore } from "@/stores/theme";

export const Route = createRootRoute({
  component: RootLayout,
});

function RootLayout() {
  const apply = useThemeStore((s) => s.apply);
  const theme = useThemeStore((s) => s.theme);
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const sectionKey = pathname.split("/").slice(0, 3).join("/") || "/";

  useStudioAutoSetup();

  useEffect(() => {
    apply();

    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onSystemChange = () => {
      if (useThemeStore.getState().theme === "system") {
        useThemeStore.getState().apply();
      }
    };

    mq.addEventListener("change", onSystemChange);
    return () => mq.removeEventListener("change", onSystemChange);
  }, []);

  useEffect(() => {
    apply();
  }, [theme, apply]);

  return (
    <div className="flex flex-col h-screen overflow-hidden bg-bg">
      <TitleBar />
      <div className="flex flex-1 overflow-hidden">
        <AppSidebar />
        <main className="relative min-w-0 flex-1 overflow-hidden bg-bg">
          <motion.div
            key={sectionKey}
            className="h-full"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
          >
            <Outlet />
          </motion.div>
        </main>
      </div>
      <Bootstrapper />
    </div>
  );
}
