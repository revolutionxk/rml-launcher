import { Link, useMatchRoute } from "@tanstack/react-router";
import { openUrl } from "@tauri-apps/plugin-opener";
import {
  BookOpen,
  Boxes,
  GitBranch,
  Home,
  MessagesSquare,
  Settings,
  type LucideIcon,
} from "lucide-react";
import { motion } from "motion/react";

import Logo from "@/components/logo";
import { Tooltip } from "@/components/ui/tooltip";
import { APP_NAME, APP_VERSION } from "@/constants/app";
import { RML_DISCORD_URL, RML_GITHUB_URL, RML_WIKI_URL } from "@/constants/links";
import { useI18n } from "@/i18n";

interface NavEntry {
  to: string;
  fuzzy?: boolean;
  icon: LucideIcon;
  labelId: string;
  activeWhen?: string[];
}

const NAV: NavEntry[] = [
  { to: "/", icon: Home, labelId: "nav-home" },
  {
    to: "/settings/instances",
    fuzzy: true,
    icon: Boxes,
    labelId: "nav-studios",
    activeWhen: ["/settings/versions"],
  },
  {
    to: "/settings/appearance",
    icon: Settings,
    labelId: "nav-settings",
    activeWhen: ["/settings/about", "/settings/engine"],
  },
];

const COMMUNITY_LINKS: { href: string; icon: LucideIcon; labelId: string }[] = [
  { href: RML_GITHUB_URL, icon: GitBranch, labelId: "nav-link-github" },
  { href: RML_WIKI_URL, icon: BookOpen, labelId: "nav-link-docs" },
  { href: RML_DISCORD_URL, icon: MessagesSquare, labelId: "nav-link-discord" },
];

function NavItem({ entry }: { entry: NavEntry }) {
  const matchRoute = useMatchRoute();
  const { t } = useI18n();
  const isActive =
    !!matchRoute({ to: entry.to, fuzzy: entry.fuzzy }) ||
    (entry.activeWhen?.some((path) => !!matchRoute({ to: path, fuzzy: true })) ?? false);
  const Icon = entry.icon;

  return (
    <Link
      to={entry.to}
      style={{ textDecoration: "none" }}
      className="relative flex items-center gap-2.5 rounded px-2.5 py-2 cursor-default outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
    >
      {isActive && (
        <motion.div
          layoutId="app-nav-pill"
          className="absolute inset-0 rounded bg-accent-muted"
          transition={{ type: "spring", stiffness: 500, damping: 40, mass: 0.75 }}
        />
      )}
      <span
        className="relative z-10 flex items-center gap-2.5 text-[12.5px] tracking-[-0.005em] transition-colors duration-100"
        style={{
          color: isActive ? "var(--color-accent)" : "var(--color-text-muted)",
          fontWeight: isActive ? 500 : 400,
        }}
      >
        <Icon size={15} className="shrink-0" />
        {t(entry.labelId)}
      </span>
    </Link>
  );
}

function CommunityLink({
  href,
  icon: Icon,
  label,
}: {
  href: string;
  icon: LucideIcon;
  label: string;
}) {
  return (
    <Tooltip.Root>
      <Tooltip.Trigger
        render={
          <button
            type="button"
            aria-label={label}
            onClick={() => openUrl(href).catch(console.error)}
            className="flex h-8 w-8 items-center justify-center rounded text-text-dim outline-none transition-colors duration-100 hover:bg-surface-2 hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
          >
            <Icon size={15} />
          </button>
        }
      />
      <Tooltip.Portal>
        <Tooltip.Positioner>
          <Tooltip.Popup>{label}</Tooltip.Popup>
        </Tooltip.Positioner>
      </Tooltip.Portal>
    </Tooltip.Root>
  );
}

export function AppSidebar() {
  const { t } = useI18n();

  return (
    <nav className="flex w-(--sidebar-w) shrink-0 flex-col border-r border-border-subtle bg-surface px-2.5 py-3">
      <div className="flex items-center gap-2.5 px-1.5 pb-1">
        <Logo size={30} />
        <div className="min-w-0">
          <div className="truncate text-[13px] font-semibold tracking-[-0.015em] text-text">
            {APP_NAME}
          </div>
          <div className="text-[10.5px] text-text-dim">
            {t("common-version", { version: APP_VERSION })}
          </div>
        </div>
      </div>

      <div className="mt-4 flex flex-col gap-0.5">
        {NAV.map((entry) => (
          <NavItem key={entry.to} entry={entry} />
        ))}
      </div>

      <div className="flex-1" />

      <Tooltip.Provider delay={300}>
        <div className="mt-1 flex items-center gap-0.5 border-t border-border-subtle px-0.5 pt-2.5">
          {COMMUNITY_LINKS.map((link) => (
            <CommunityLink
              key={link.labelId}
              href={link.href}
              icon={link.icon}
              label={t(link.labelId)}
            />
          ))}
        </div>
      </Tooltip.Provider>
    </nav>
  );
}
