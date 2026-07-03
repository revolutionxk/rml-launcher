import { openUrl } from "@tauri-apps/plugin-opener";
import { ExternalLink, GitBranchIcon } from "lucide-react";

import Logo from "@/components/logo";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { APP_NAME, APP_VERSION } from "@/constants/app";
import { LINKS } from "@/constants/links";
import { useI18n } from "@/i18n";

export function AboutSection() {
  const { t } = useI18n();

  return (
    <Card.Root>
      <Card.Header>
        <Card.Label>{t("about-title")}</Card.Label>
      </Card.Header>
      <Card.Body className="flex flex-col gap-4">
        <div className="flex items-center gap-3">
          <Logo size={38} />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-[14px] font-semibold tracking-[-0.01em] text-text">
                {APP_NAME}
              </span>
              <Badge.Root variant="blue">
                <Badge.Icon>
                  <GitBranchIcon size={10} />
                </Badge.Icon>
                <Badge.Label>{__APP_GIT_HASH__}</Badge.Label>
              </Badge.Root>
            </div>
            <div className="mt-0.5 text-[11.5px] text-text-muted">
              {t("common-version", { version: APP_VERSION })}
            </div>
          </div>
        </div>

        <p className="text-[12px] leading-relaxed text-text-muted">{t("about-app-description")}</p>

        <div className="flex flex-wrap gap-1.5">
          {LINKS.map((link) => (
            <button
              key={link.labelId}
              type="button"
              onClick={() => openUrl(link.href).catch(console.error)}
              className="group inline-flex items-center gap-1.5 rounded-sm border border-border bg-surface px-2.5 py-1.5 text-[11.5px] text-text-muted outline-none transition-colors hover:bg-surface-2 hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
            >
              <span className="flex items-center justify-center text-text-dim transition-colors group-hover:text-text-muted [&_svg]:h-3.5 [&_svg]:w-3.5">
                {link.icon}
              </span>
              {t(link.labelId)}
              <ExternalLink size={10} className="opacity-40" />
            </button>
          ))}
        </div>

        <div className="text-[11px] text-text-dim">{t("about-disclaimer")}</div>
      </Card.Body>
    </Card.Root>
  );
}
