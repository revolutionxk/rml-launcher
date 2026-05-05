import { createFileRoute } from "@tanstack/react-router";
import { openUrl } from "@tauri-apps/plugin-opener";
import { ExternalLink, GitBranchIcon } from "lucide-react";
import { motion } from "motion/react";

import Logo from "@/components/logo";
import { Badge } from "@/components/ui/badge";
import { APP_NAME, APP_VERSION } from "@/constants/app";
import { LINKS } from "@/constants/links";
import { useI18n } from "@/i18n";

export const Route = createFileRoute("/settings/about")({
  component: AboutPage,
});

function AboutPage() {
  const { t } = useI18n();
  const handleLink = (href: string) => openUrl(href).catch(console.error);

  return (
    <div>
      <div className="mb-5">
        <h1 className="text-[18px] font-semibold text-text tracking-[-0.018em] leading-[1.25]">
          {t("about-title")}
        </h1>
        <p className="text-[12.5px] text-text-muted mt-1 leading-normal">
          {t("about-description")}
        </p>
      </div>

      <motion.div
        className="flex flex-col items-center gap-3.5 p-7 text-center bg-card border border-border rounded-lg mb-3"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.25 }}
      >
        <Logo size={64} />
        <div>
          <div className="text-[17px] font-semibold text-text tracking-[-0.018em]">{APP_NAME}</div>
          <div className="text-[12.5px] text-text-muted mt-1">
            {t("common-version", { version: APP_VERSION })}
          </div>
        </div>
        <div className="text-xs text-text-muted max-w-75 leading-[1.6]">
          {t("about-app-description")}
        </div>

        <div className="flex gap-2 flex-wrap justify-center">
          <Badge.Root variant="blue">
            <Badge.Icon>
              <GitBranchIcon size={12} />
            </Badge.Icon>
            <Badge.Label>{__APP_GIT_HASH__}</Badge.Label>
          </Badge.Root>
        </div>
      </motion.div>

      <div className="grid grid-cols-2 gap-2">
        {LINKS.map((link, i) => (
          <motion.button
            key={link.labelId}
            className="about-link-card flex items-center gap-2.5 px-4 py-3.25 bg-card border border-border rounded cursor-pointer w-full text-left transition-[background,border-color] duration-150 hover:bg-card-hover hover:border-[#333]"
            onClick={() => handleLink(link.href)}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.06 + i * 0.05, duration: 0.2 }}
            whileTap={{ scale: 0.97 }}
          >
            <div className="w-8.5 h-8.5 flex items-center justify-center rounded-sm icon-box--blue shrink-0">
              {link.icon}
            </div>
            <div className="flex-1 text-left">
              <div className="text-[13px] font-semibold text-text">{t(link.labelId)}</div>
              <div className="text-[11.5px] text-text-muted">{t(link.descriptionId)}</div>
            </div>
            <ExternalLink size={13} className="text-text-dim" />
          </motion.button>
        ))}
      </div>

      <div className="text-center text-[11px] text-text-dim mt-5">{t("about-disclaimer")}</div>
    </div>
  );
}
