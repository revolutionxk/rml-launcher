import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { openUrl } from "@tauri-apps/plugin-opener";
import { Play, Download, Settings, HelpCircle, ExternalLink } from "lucide-react";
import { motion } from "motion/react";
import { useState } from "react";

import ActionButton from "@/components/action-button";
import Logo from "@/components/logo";
import { APP_NAME, APP_VERSION } from "@/constants/app";
import { LINKS, RML_WIKI_URL } from "@/constants/links";
import { useI18n } from "@/i18n";
import { launchStudio, listStudioVersions } from "@/lib/studio";

export const Route = createFileRoute("/")({
  component: HomePage,
});

function HomePage() {
  const navigate = useNavigate();
  const { t } = useI18n();
  const [isLaunching, setIsLaunching] = useState(false);

  const handleLink = (href: string) => {
    openUrl(href).catch(console.error);
  };

  const handleLaunch = async () => {
    setIsLaunching(true);

    try {
      const versions = await listStudioVersions();
      const preferredInstalled =
        versions.find(
          (version) => version.isInstalled && version.isDefault && version.executablePath,
        ) ?? versions.find((version) => version.isInstalled && version.executablePath);

      if (!preferredInstalled) {
        navigate({ to: "/settings/versions" });
        return;
      }

      await launchStudio(preferredInstalled.versionGuid);
    } catch (error) {
      console.error(error);
    } finally {
      setIsLaunching(false);
    }
  };

  return (
    <motion.div
      className="home-page flex h-full overflow-hidden relative"
      initial={{ opacity: 0, x: -16 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.2, ease: [0.25, 0.1, 0.25, 1] }}
    >
      <div className="w-68 shrink-0 flex flex-col px-6 py-7 border-r border-border-subtle bg-surface relative">
        <motion.div
          className="flex items-center gap-3 mb-6"
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.05, duration: 0.25 }}
        >
          <Logo size={44} />
          <div className="flex flex-col gap-0.5">
            <div className="text-[15px] font-semibold text-text tracking-[-0.018em]">
              {APP_NAME}
            </div>
            <div className="text-[11.5px] text-text-muted">
              {t("common-version", { version: APP_VERSION })}
            </div>
          </div>
        </motion.div>

        <div className="h-px bg-border-subtle mb-4" />

        <motion.div
          className="flex flex-col gap-0.5"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.1, duration: 0.25 }}
        >
          {LINKS.map((link) => (
            <button
              key={link.labelId}
              className="flex items-center gap-2 px-2.5 py-2 rounded-sm text-text-muted text-[12.5px] cursor-pointer bg-transparent border-none text-left w-full transition-[background,color] duration-120 hover:bg-surface-2 hover:text-text [&_svg]:shrink-0"
              onClick={() => handleLink(link.href)}
            >
              {link.icon}
              <span>{t(link.labelId)}</span>
              <ExternalLink size={10} className="ml-auto opacity-35" />
            </button>
          ))}
        </motion.div>
      </div>

      <div className="flex-1 flex flex-col justify-center px-7 py-6 gap-1.5">
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.07, duration: 0.24 }}
        >
          <ActionButton
            icon={<Play size={16} />}
            iconClass="icon-box--blue"
            label={t("home-action-launch-label")}
            description={t("home-action-launch-description")}
            onClick={() => {
              void handleLaunch();
            }}
            disabled={isLaunching}
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.11, duration: 0.24 }}
        >
          <ActionButton
            icon={<Download size={16} />}
            iconClass="icon-box--purple"
            label={t("home-action-versions-label")}
            description={t("home-action-versions-description")}
            onClick={() => navigate({ to: "/settings/versions" })}
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15, duration: 0.24 }}
        >
          <ActionButton
            icon={<Settings size={16} />}
            iconClass="icon-box--gray"
            label={t("home-action-settings-label")}
            description={t("home-action-settings-description")}
            onClick={() => navigate({ to: "/settings/instances" })}
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.19, duration: 0.24 }}
        >
          <ActionButton
            icon={<HelpCircle size={16} />}
            iconClass="icon-box--orange"
            label={t("home-action-help-label")}
            description={t("home-action-help-description")}
            onClick={() => handleLink(RML_WIKI_URL)}
          />
        </motion.div>
      </div>
    </motion.div>
  );
}
