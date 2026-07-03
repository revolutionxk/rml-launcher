import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/settings")({
  component: SettingsLayout,
});

function SettingsLayout() {
  return (
    <div
      className="h-full overflow-y-auto px-5 py-4 lg:px-7 lg:py-7"
      style={{ scrollbarGutter: "stable" }}
    >
      <Outlet />
    </div>
  );
}
