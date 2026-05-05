import { createRootRoute, Outlet } from "@tanstack/react-router";
import { useEffect } from "react";

import TitleBar from "@/components/title-bar";
import { useThemeStore } from "@/stores/theme";

export const Route = createRootRoute({
  component: RootLayout,
});

function RootLayout() {
  const apply = useThemeStore((s) => s.apply);
  const theme = useThemeStore((s) => s.theme);

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
      <div className="flex-1 overflow-hidden relative">
        <Outlet />
      </div>
    </div>
  );
}
