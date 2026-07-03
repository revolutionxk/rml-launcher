import { listen } from "@tauri-apps/api/event";
import { AlertCircle, CheckCircle2 } from "lucide-react";
import { AnimatePresence, motion, type Variants } from "motion/react";
import { type ReactNode, useEffect, useState } from "react";

import Logo from "@/components/logo";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/i18n";
import { formatBytes } from "@/lib/format";
import type { StudioInstallProgress } from "@/lib/studio";
import { cn } from "@/lib/utils";

const STUDIO_INSTALL_EVENT = "studio-install-progress";

const EASE_OUT = [0.22, 1, 0.36, 1] as const;

const stageContainer: Variants = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.09, delayChildren: 0.06 } },
};

const stageItem: Variants = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.5, ease: EASE_OUT } },
};

interface BootstrapperViewProps {
  title: string;
  subtitle?: ReactNode;
  statusLabel?: string;
  detailLabel?: string;
  percent: number;
  indeterminate?: boolean;
  failed?: boolean;
  done?: boolean;
  onClose?: () => void;
  closeLabel?: string;
  className?: string;
}

function BootMark({ failed, done }: { failed?: boolean; done?: boolean }) {
  if (done) {
    return (
      <motion.div
        className="flex h-17 w-17 items-center justify-center rounded-full text-green"
        initial={{ scale: 0.4, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ type: "spring", stiffness: 380, damping: 20 }}
      >
        <CheckCircle2 size={46} strokeWidth={1.6} />
      </motion.div>
    );
  }

  if (failed) {
    return (
      <div className="flex h-17 w-17 items-center justify-center rounded-full text-red">
        <AlertCircle size={36} />
      </div>
    );
  }

  return (
    <div className="relative flex h-20 w-20 items-center justify-center">
      <motion.div
        className="absolute h-20 w-20 rounded-full"
        style={{
          background:
            "conic-gradient(from 0deg, transparent 0%, var(--color-accent) 90%, transparent 100%)",
          opacity: 0.55,
        }}
        animate={{ rotate: 360 }}
        transition={{ repeat: Infinity, duration: 2.4, ease: "linear" }}
      />
      <div className="relative flex h-17 w-17 items-center justify-center rounded-full bg-bg">
        <Logo size={48} />
      </div>
    </div>
  );
}

export function BootstrapperView({
  title,
  subtitle,
  statusLabel,
  detailLabel,
  percent,
  indeterminate,
  failed,
  done,
  onClose,
  closeLabel,
  className,
}: BootstrapperViewProps) {
  const clamped = Math.min(100, Math.max(0, Math.round(percent)));

  return (
    <div
      className={cn(
        "absolute inset-0 flex flex-col items-center justify-center overflow-hidden bg-bg px-8",
        className,
      )}
    >
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse 60% 55% at 50% 40%, color-mix(in srgb, var(--color-accent) 9%, transparent) 0%, transparent 70%)",
        }}
      />

      <motion.div
        className="relative flex w-full max-w-sm flex-col items-center"
        variants={stageContainer}
        initial="hidden"
        animate="show"
      >
        <motion.div variants={stageItem}>
          <BootMark failed={failed} done={done} />
        </motion.div>

        <motion.div variants={stageItem} className="mt-6 flex min-h-12 flex-col text-center">
          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={title}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.22, ease: EASE_OUT }}
            >
              <div className="text-[16px] font-semibold tracking-[-0.01em] text-text">{title}</div>
              {subtitle && <div className="mt-1 text-[12.5px] text-text-muted">{subtitle}</div>}
            </motion.div>
          </AnimatePresence>
        </motion.div>

        <motion.div variants={stageItem} className="mt-6 flex min-h-9 w-full items-start">
          {failed ? (
            onClose && (
              <div className="flex w-full justify-center">
                <Button.Root variant="ghost" onClick={onClose}>
                  <Button.Label>{closeLabel}</Button.Label>
                </Button.Root>
              </div>
            )
          ) : done ? null : (
            <div className="w-full">
              {indeterminate ? (
                <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-surface-2">
                  <div className="animate-bootstrapper-slide absolute inset-y-0 w-1/3 rounded-full bg-accent" />
                </div>
              ) : (
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-surface-2">
                  <div
                    className="h-full rounded-full bg-accent transition-[width] duration-300 ease-out"
                    style={{ width: `${clamped}%` }}
                  />
                </div>
              )}

              {(statusLabel || detailLabel) && (
                <div className="mt-2.5 flex items-center justify-between gap-3 text-[11.5px] text-text-muted">
                  <AnimatePresence mode="wait" initial={false}>
                    <motion.span
                      key={statusLabel}
                      className="min-w-0 truncate"
                      initial={{ opacity: 0, y: 4 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -4 }}
                      transition={{ duration: 0.18 }}
                    >
                      {statusLabel}
                    </motion.span>
                  </AnimatePresence>
                  <span className="shrink-0 tabular-nums text-text-dim">
                    {detailLabel || (indeterminate ? "" : `${clamped}%`)}
                  </span>
                </div>
              )}
            </div>
          )}
        </motion.div>
      </motion.div>
    </div>
  );
}

export function Bootstrapper() {
  const { t } = useI18n();
  const [progress, setProgress] = useState<StudioInstallProgress | null>(null);

  useEffect(() => {
    let disposed = false;
    const unlistenPromise = listen<StudioInstallProgress>(STUDIO_INSTALL_EVENT, ({ payload }) => {
      if (disposed) {
        return;
      }
      if (payload.phase === "completed") {
        setProgress(null);
        return;
      }
      setProgress(payload);
    });

    return () => {
      disposed = true;
      void unlistenPromise.then((unlisten) => unlisten());
    };
  }, []);

  return (
    <AnimatePresence>
      {progress && (
        <motion.div
          key="bootstrapper"
          className="fixed inset-x-0 bottom-0 top-(--titlebar-h) z-50"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          <BootstrapperView
            failed={progress.phase === "failed"}
            title={
              progress.phase === "failed"
                ? t("bootstrapper-failed-title")
                : t("bootstrapper-title-installing")
            }
            subtitle={
              progress.phase === "failed"
                ? (progress.error ?? t("bootstrapper-failed-generic"))
                : t("bootstrapper-version", { version: progress.version })
            }
            statusLabel={installStatusLabel(progress, t)}
            detailLabel={installDetailLabel(progress, t)}
            percent={progress.progress}
            indeterminate={progress.phase === "resolving"}
            onClose={() => setProgress(null)}
            closeLabel={t("bootstrapper-failed-close")}
          />
        </motion.div>
      )}
    </AnimatePresence>
  );
}

type Translate = ReturnType<typeof useI18n>["t"];

export function installStatusLabel(progress: StudioInstallProgress, t: Translate): string {
  switch (progress.phase) {
    case "resolving":
      return t("bootstrapper-phase-resolving");
    case "downloading":
      return t("bootstrapper-phase-downloading");
    case "extracting":
      return t("bootstrapper-phase-extracting");
    case "finalizing":
      return t("bootstrapper-phase-finalizing");
    default:
      return "";
  }
}

export function installDetailLabel(progress: StudioInstallProgress, t: Translate): string {
  if (progress.phase === "downloading" && progress.totalDownloadBytes > 0) {
    return `${formatBytes(progress.downloadedBytes)} / ${formatBytes(progress.totalDownloadBytes)}`;
  }
  if (progress.phase === "extracting" && progress.totalPackages > 0) {
    return t("bootstrapper-detail-packages", {
      done: progress.extractedPackages,
      total: progress.totalPackages,
    });
  }
  return progress.currentPackage?.replace(/\.zip$/i, "") ?? "";
}
