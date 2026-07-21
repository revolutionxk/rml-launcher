import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { openUrl } from "@tauri-apps/plugin-opener";
import {
  ArrowRight,
  Download,
  Package,
  Play,
  Puzzle,
  RefreshCw,
  Settings2,
  ShieldCheck,
  Star,
} from "lucide-react";
import { motion } from "motion/react";
import { useState } from "react";

import { PlatformNotice } from "@/components/platform-notice";
import Logo from "@/components/logo";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Callout } from "@/components/ui/callout";
import { SetupPath, type SetupStep } from "@/components/ui/setup-path";
import { LoadingState } from "@/components/ui/spinner";
import { RML_DISCORD_URL, RML_WIKI_URL } from "@/constants/links";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import type { InstanceSummary } from "@/lib/instances";
import { useHostInfo, useInstances } from "@/lib/queries";
import { launchStudio } from "@/lib/studio";
import { useSetupStore } from "@/stores/setup";

export const Route = createFileRoute("/")({
  component: HomePage,
});

const SETUP_STEP_COUNT = 2;

function HomePage() {
  const navigate = useNavigate();
  const { t } = useI18n();
  const { data: host } = useHostInfo();
  const { data: instances = [], isLoading } = useInstances();

  const [launchingId, setLaunchingId] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const readyInstances = instances.filter((instance) => instance.executablePath);
  const target =
    readyInstances.find((instance) => instance.isDefault) ?? readyInstances[0] ?? null;

  const loaderDeferred = useSetupStore((s) => s.loaderDeferred);
  const deferLoader = useSetupStore((s) => s.deferLoader);

  const hasStudio = readyInstances.length > 0;
  const hasLoader = Boolean(target?.modloader);
  const hasMods = (target?.modsTotal ?? 0) > 0;
  const doneCount = [hasStudio, hasLoader].filter(Boolean).length;
  
  const setupUsable = hasStudio && (hasLoader || loaderDeferred);

  const isLinux = host?.os === "linux";

  const handleLaunch = async (versionGuid: string) => {
    setLaunchingId(versionGuid);
    setErrorMessage(null);
    try {
      await launchStudio(versionGuid);
    } catch (error) {
      setErrorMessage(
        t("instances-error-launch", {
          message: getErrorMessage(error, t("instances-error-generic")),
        }),
      );
    } finally {
      setLaunchingId(null);
    }
  };

  const openInstance = (versionGuid: string) =>
    navigate({ to: "/settings/instances/$versionGuid", params: { versionGuid } });

  const setupSteps: SetupStep[] = (() => {
    const definitions = [
      {
        id: "studio",
        done: hasStudio,
        title: t("home-step-studio-title"),
        description: t("home-step-studio-description"),
        action: {
          label: t("home-step-studio-action"),
          icon: <Download size={14} />,
          onClick: () => navigate({ to: "/settings/versions" }),
        },
        secondaryAction: undefined as SetupStep["secondaryAction"],
        hint: undefined as SetupStep["hint"],
      },
      {
        id: "loader",
        done: hasLoader,
        title: t("home-step-loader-title"),
        description: t("home-step-loader-description"),
        action: {
          label: t("home-step-loader-action"),
          icon: <ShieldCheck size={14} />,
          onClick: () => target && openInstance(target.versionGuid),
        },
        secondaryAction: {
          label: t("home-step-loader-skip"),
          onClick: deferLoader,
        },
        hint: t("home-step-loader-hint") as SetupStep["hint"],
      },
    ];

    const currentIndex = definitions.findIndex((step) => !step.done);

    return definitions.map((step, index) => {
      const isCurrent = index === currentIndex && !step.done;
      return {
        id: step.id,
        title: step.title,
        description: step.description,
        status: step.done ? "done" : index === currentIndex ? "current" : "locked",
        action: isCurrent ? step.action : undefined,
        secondaryAction: isCurrent ? step.secondaryAction : undefined,
        hint: isCurrent ? step.hint : undefined,
      };
    });
  })();

  return (
    <div
      className="h-full overflow-y-auto px-5 py-5 lg:px-8 lg:py-8"
      style={{ scrollbarGutter: "stable" }}
    >
      <motion.div
        className="mx-auto flex w-full max-w-3xl flex-col gap-7"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.24, ease: [0.25, 0.1, 0.25, 1] }}
      >
        <header className="flex items-start gap-4">
          <div className="mt-0.5 shrink-0">
            <Logo size={48} />
          </div>
          <div className="min-w-0">
            <h1 className="text-[22px] font-semibold leading-[1.2] tracking-[-0.02em] text-text">
              {t("home-hero-title")}
            </h1>
            <p className="mt-1.5 max-w-xl text-[13px] leading-relaxed text-text-muted">
              {t("home-hero-subtitle")}
            </p>
          </div>
        </header>

        <PlatformNotice />

        {errorMessage && <Callout variant="danger">{errorMessage}</Callout>}

        {isLoading ? (
          <LoadingState label={t("home-loading")} />
        ) : isLinux ? (
          <Callout
            variant="info"
            title={t("vinegar-studio-title")}
            action={
              <Button.Root
                variant="primary"
                onClick={() => navigate({ to: "/settings/instances" })}
              >
                <Button.Label>{t("nav-studios")}</Button.Label>
                <Button.Icon>
                  <ArrowRight size={14} />
                </Button.Icon>
              </Button.Root>
            }
          >
            {t("vinegar-studio-description")}
          </Callout>
        ) : setupUsable && target ? (
          <ReadyDashboard
            target={target}
            instances={readyInstances}
            launchingId={launchingId}
            hasLoader={hasLoader}
            hasMods={hasMods}
            onLaunch={handleLaunch}
            onConfigure={openInstance}
            onOpenTarget={() => openInstance(target.versionGuid)}
            t={t}
          />
        ) : (
          <section className="rounded-lg border border-border bg-card p-6 shadow-(--card-shadow)">
            <div className="mb-1 flex items-center justify-between gap-3">
              <h2 className="text-[15px] font-semibold tracking-[-0.01em] text-text">
                {t("home-setup-title")}
              </h2>
              <span className="rounded-full bg-surface-2 px-2.5 py-1 text-[10.5px] font-medium tabular-nums text-text-muted">
                {t("home-setup-progress", { done: doneCount, total: SETUP_STEP_COUNT })}
              </span>
            </div>
            <div className="mb-6 h-1.5 overflow-hidden rounded-full bg-surface-2">
              <motion.div
                className="h-full rounded-full bg-accent"
                initial={false}
                animate={{ width: `${(doneCount / SETUP_STEP_COUNT) * 100}%` }}
                transition={{ type: "spring", stiffness: 200, damping: 30 }}
              />
            </div>

            <SetupPath steps={setupSteps} />

            {hasStudio && target && (
              <div className="mt-5 border-t border-border-subtle pt-4">
                <button
                  type="button"
                  className="inline-flex items-center gap-2 rounded-sm text-[12px] text-text-muted outline-none transition-colors hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
                  disabled={launchingId !== null}
                  onClick={() => void handleLaunch(target.versionGuid)}
                >
                  {launchingId === target.versionGuid ? (
                    <RefreshCw size={13} className="animate-spin" />
                  ) : (
                    <Play size={13} />
                  )}
                  {t("home-setup-skip")}
                </button>
              </div>
            )}
          </section>
        )}
      </motion.div>
    </div>
  );
}

interface ReadyDashboardProps {
  target: InstanceSummary;
  instances: InstanceSummary[];
  launchingId: string | null;
  hasLoader: boolean;
  hasMods: boolean;
  onLaunch: (versionGuid: string) => void;
  onConfigure: (versionGuid: string) => void;
  onOpenTarget: () => void;
  t: ReturnType<typeof useI18n>["t"];
}

function ReadyDashboard({
  target,
  instances,
  launchingId,
  hasLoader,
  hasMods,
  onLaunch,
  onConfigure,
  onOpenTarget,
  t,
}: ReadyDashboardProps) {
  const subtitle = !target.isDefault
    ? t("home-ready-no-default")
    : t(hasLoader && hasMods ? "home-ready-subtitle" : "home-ready-subtitle-plain", {
        version: t("versions-studio-label", { version: target.version }),
      });

  return (
    <div className="flex flex-col gap-6">
      <section
        className="rounded-lg border p-6"
        style={{
          borderColor: "color-mix(in srgb, var(--color-accent) 30%, transparent)",
          backgroundColor: "color-mix(in srgb, var(--color-accent) 6%, transparent)",
        }}
      >
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg icon-box--blue">
            <Play size={22} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-[10.5px] font-semibold uppercase tracking-[0.08em] text-green">
              {t("home-ready-eyebrow")}
            </div>
            <div className="text-[18px] font-semibold leading-tight tracking-[-0.015em] text-text">
              {t("home-ready-title")}
            </div>
            <div className="mt-0.5 text-[12.5px] text-text-muted">{subtitle}</div>
          </div>
          <Button.Root
            variant="primary"
            className="px-5 py-2.5 text-[13px]"
            disabled={launchingId !== null}
            onClick={() => onLaunch(target.versionGuid)}
          >
            <Button.Icon>
              {launchingId === target.versionGuid ? (
                <RefreshCw size={15} className="animate-spin" />
              ) : (
                <Play size={15} />
              )}
            </Button.Icon>
            <Button.Label>{t("home-ready-launch")}</Button.Label>
          </Button.Root>
        </div>
      </section>

      {!hasLoader ? (
        <Callout
          variant="info"
          title={t("home-unlock-title")}
          action={
            <Button.Root variant="primary" onClick={onOpenTarget}>
              <Button.Icon>
                <ShieldCheck size={14} />
              </Button.Icon>
              <Button.Label>{t("home-unlock-action")}</Button.Label>
            </Button.Root>
          }
        >
          {t("home-unlock-description")}
        </Callout>
      ) : !hasMods ? (
        <Callout
          variant="info"
          title={t("home-ready-add-mods-title")}
          action={
            <Button.Root variant="primary" onClick={onOpenTarget}>
              <Button.Icon>
                <Puzzle size={14} />
              </Button.Icon>
              <Button.Label>{t("home-ready-manage")}</Button.Label>
            </Button.Root>
          }
        >
          {t("home-ready-add-mods-description")}{" "}
          <button
            type="button"
            className="text-accent underline-offset-2 hover:underline"
            onClick={() => openUrl(RML_WIKI_URL).catch(console.error)}
          >
            {t("nav-link-docs")}
          </button>
          {" · "}
          <button
            type="button"
            className="text-accent underline-offset-2 hover:underline"
            onClick={() => openUrl(RML_DISCORD_URL).catch(console.error)}
          >
            {t("nav-link-discord")}
          </button>
        </Callout>
      ) : null}

      {instances.length > 0 && (
        <section className="flex flex-col gap-2.5">
          <h2 className="text-[11px] font-semibold uppercase tracking-[0.08em] text-text-dim">
            {t("home-ready-section-setups")}
          </h2>
          <div className="flex flex-col gap-2">
            {instances.map((instance) => (
              <InstanceRow
                key={instance.versionGuid}
                instance={instance}
                isLaunching={launchingId === instance.versionGuid}
                onLaunch={() => onLaunch(instance.versionGuid)}
                onConfigure={() => onConfigure(instance.versionGuid)}
                t={t}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

interface InstanceRowProps {
  instance: InstanceSummary;
  isLaunching: boolean;
  onLaunch: () => void;
  onConfigure: () => void;
  t: ReturnType<typeof useI18n>["t"];
}

function InstanceRow({ instance, isLaunching, onLaunch, onConfigure, t }: InstanceRowProps) {
  return (
    <div className="flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-3 transition-colors duration-150 hover:border-[#2e2e2e] hover:bg-card-hover">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-sm icon-box--blue">
        <Package size={17} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="truncate text-[13px] font-semibold tracking-[-0.01em] text-text">
            {t("versions-studio-label", { version: instance.version })}
          </span>
          {instance.isDefault && (
            <Badge.Root variant="yellow">
              <Badge.Icon>
                <Star size={9} />
              </Badge.Icon>
              <Badge.Label>{t("versions-badge-default")}</Badge.Label>
            </Badge.Root>
          )}
        </div>
        <div className="mt-0.5 flex flex-wrap items-center gap-1.5 text-[11px] text-text-muted">
          {instance.modloader ? (
            <span className="inline-flex items-center gap-1 text-green">
              <ShieldCheck size={11} />
              {instance.modloader.name}
            </span>
          ) : (
            <span>{t("instances-no-loader")}</span>
          )}
          <span aria-hidden>·</span>
          <span className="inline-flex items-center gap-1">
            <Puzzle size={11} />
            {t("instances-mods-count", {
              enabled: instance.modsEnabled,
              total: instance.modsTotal,
            })}
          </span>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-1.5">
        <Button.Root variant="primary" size="sm" disabled={isLaunching} onClick={onLaunch}>
          <Button.Icon>
            {isLaunching ? (
              <RefreshCw size={12} className="animate-spin" />
            ) : (
              <Play size={12} />
            )}
          </Button.Icon>
          <Button.Label>{t("instances-launch")}</Button.Label>
        </Button.Root>
        <Button.Root
          variant="ghost"
          size="icon-sm"
          aria-label={t("home-ready-configure")}
          onClick={onConfigure}
        >
          <Button.Icon>
            <Settings2 size={13} />
          </Button.Icon>
        </Button.Root>
      </div>
    </div>
  );
}
