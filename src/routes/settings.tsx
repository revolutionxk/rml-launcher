import { createFileRoute, Link, Outlet, useMatchRoute, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, Package, Boxes, Cpu, Palette, Info } from "lucide-react";
import { motion } from "motion/react";

import { useI18n } from "@/i18n";

export const Route = createFileRoute("/settings")({
  component: SettingsLayout,
});

const NAV_ITEMS = [
  {
    to: "/settings/versions" as const,
    icon: <Package size={14} />,
    labelId: "settings-nav-versions",
  },
  {
    to: "/settings/instances" as const,
    icon: <Boxes size={14} />,
    labelId: "settings-nav-instances",
  },
  {
    to: "/settings/engine" as const,
    icon: <Cpu size={14} />,
    labelId: "settings-nav-engine",
  },
  {
    to: "/settings/appearance" as const,
    icon: <Palette size={14} />,
    labelId: "settings-nav-appearance",
  },
] as const;

const ALL_ROUTES = [...NAV_ITEMS.map((i) => i.to), "/settings/about"] as const;

function NavItem({
  to,
  icon,
  label,
}: {
  to: (typeof ALL_ROUTES)[number];
  icon: React.ReactNode;
  label: string;
}) {
  const matchRoute = useMatchRoute();
  const isActive = !!matchRoute({ to });

  return (
    <Link
      to={to}
      style={{ textDecoration: "none" }}
      className="relative flex items-center gap-2 px-2.5 py-[6px] rounded-sm w-full cursor-default"
    >
      {isActive && (
        <motion.div
          layoutId="nav-pill"
          className="absolute inset-0 rounded-sm bg-accent-muted"
          transition={{ type: "spring", stiffness: 500, damping: 40, mass: 0.75 }}
        />
      )}
      <span
        className="relative z-10 flex items-center gap-2 text-[12.5px] tracking-[-0.005em] transition-colors duration-100"
        style={{
          color: isActive ? "var(--color-accent)" : "var(--color-text-muted)",
          fontWeight: isActive ? 500 : 400,
        }}
      >
        {icon}
        {label}
      </span>
    </Link>
  );
}

function SettingsLayout() {
  const navigate = useNavigate();
  const { t } = useI18n();

  return (
    <div className="h-full">
      <div className="flex h-full overflow-hidden">
        <nav className="w-(--sidebar-w) shrink-0 flex flex-col py-3 px-2 border-r border-border-subtle bg-surface overflow-y-auto">
          <motion.button
            className="sidebar-nav-item text-[12.5px] mb-1"
            onClick={() => navigate({ to: "/" })}
            whileTap={{ x: -2 }}
            transition={{ type: "spring", stiffness: 600, damping: 30 }}
          >
            <ArrowLeft size={13} />
            {t("common-back")}
          </motion.button>

          <div className="text-[10.5px] font-semibold uppercase tracking-[0.09em] text-text-dim px-2.5 pt-3 pb-1.5">
            {t("common-settings")}
          </div>

          {NAV_ITEMS.map((item) => (
            <NavItem key={item.to} to={item.to} icon={item.icon} label={t(item.labelId)} />
          ))}

          <div className="flex-1" />
          <div className="h-px bg-border-subtle my-2 mx-1.5" />

          <NavItem to="/settings/about" icon={<Info size={14} />} label={t("settings-nav-about")} />
        </nav>

        <div className="flex-1 overflow-y-auto px-6 py-6">
          <Outlet />
        </div>
      </div>
    </div>
  );
}
