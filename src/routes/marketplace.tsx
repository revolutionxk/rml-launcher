import { createFileRoute } from "@tanstack/react-router";
import { motion } from "motion/react";

import { useI18n } from "@/i18n";

export const Route = createFileRoute("/marketplace")({
  component: RouteComponent,
});

function RouteComponent() {
  const { t } = useI18n();

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.18, ease: [0.25, 0.1, 0.25, 1] }}
    >
      <div className="mb-5">
        <h1 className="text-[18px] font-semibold text-text tracking-[-0.018em] leading-[1.25]">
          {t("marketplace-title")}
        </h1>
        <p className="text-[12.5px] text-text-muted mt-1 leading-normal">
          {t("marketplace-description")}
        </p>
      </div>

      <div className="bg-card border border-border rounded-lg px-5 py-6 text-[13px] text-text-muted">
        {t("marketplace-empty")}
      </div>
    </motion.div>
  );
}
