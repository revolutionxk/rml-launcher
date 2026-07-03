import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ArrowRight, Store } from "lucide-react";
import { motion } from "motion/react";

import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { useI18n } from "@/i18n";

export const Route = createFileRoute("/marketplace")({
  component: RouteComponent,
});

function RouteComponent() {
  const { t } = useI18n();
  const navigate = useNavigate();

  return (
    <div className="h-full overflow-y-auto px-7 py-7" style={{ scrollbarGutter: "stable" }}>
      <motion.div
        className="mx-auto flex w-full max-w-3xl flex-col gap-5"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.18, ease: [0.25, 0.1, 0.25, 1] }}
      >
        <PageHeader title={t("marketplace-title")} description={t("marketplace-description")} />

        <EmptyState
          icon={<Store size={26} />}
          title={t("marketplace-title")}
          description={t("marketplace-empty")}
          action={
            <Button.Root variant="primary" onClick={() => navigate({ to: "/settings/instances" })}>
              <Button.Label>{t("nav-studios")}</Button.Label>
              <Button.Icon>
                <ArrowRight size={14} />
              </Button.Icon>
            </Button.Root>
          }
        />
      </motion.div>
    </div>
  );
}
