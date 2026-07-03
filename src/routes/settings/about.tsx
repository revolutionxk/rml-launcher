import { createFileRoute } from "@tanstack/react-router";

import { AboutSection } from "@/components/about-section";
import { PageHeader } from "@/components/ui/page-header";
import { useI18n } from "@/i18n";

export const Route = createFileRoute("/settings/about")({
  component: AboutPage,
});

function AboutPage() {
  const { t } = useI18n();

  return (
    <div>
      <PageHeader className="mb-5" title={t("about-title")} description={t("about-description")} />
      <AboutSection />
    </div>
  );
}
