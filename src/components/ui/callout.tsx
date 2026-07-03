import { AlertCircle, AlertTriangle, CheckCircle2, Info, X, type LucideIcon } from "lucide-react";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

export type CalloutVariant = "info" | "success" | "warning" | "danger" | "neutral";

const variantStyles: Record<
  CalloutVariant,
  { container: string; icon: string; defaultIcon: LucideIcon }
> = {
  info: {
    container: "border-accent/25 bg-accent-muted",
    icon: "text-accent",
    defaultIcon: Info,
  },
  success: {
    container: "border-green/25 bg-green-muted",
    icon: "text-green",
    defaultIcon: CheckCircle2,
  },
  warning: {
    container: "border-yellow/25 bg-yellow-muted",
    icon: "text-yellow",
    defaultIcon: AlertTriangle,
  },
  danger: {
    container: "border-red/25 bg-red-muted",
    icon: "text-red",
    defaultIcon: AlertCircle,
  },
  neutral: {
    container: "border-border bg-surface-2",
    icon: "text-text-muted",
    defaultIcon: Info,
  },
};

interface CalloutProps {
  variant?: CalloutVariant;
  title?: ReactNode;
  children?: ReactNode;
  icon?: LucideIcon | null;
  action?: ReactNode;
  onDismiss?: () => void;
  dismissLabel?: string;
  className?: string;
}

export function Callout({
  variant = "info",
  title,
  children,
  icon,
  action,
  onDismiss,
  dismissLabel = "Dismiss",
  className,
}: CalloutProps) {
  const styles = variantStyles[variant];
  const IconComponent = icon === null ? null : (icon ?? styles.defaultIcon);

  return (
    <div
      className={cn(
        "flex items-start gap-2.5 rounded border px-3.5 py-3",
        styles.container,
        className,
      )}
    >
      {IconComponent && (
        <IconComponent size={15} className={cn("mt-px shrink-0", styles.icon)} />
      )}
      <div className="min-w-0 flex-1">
        {title && (
          <div className="text-[12.5px] font-semibold leading-[1.35] text-text">{title}</div>
        )}
        {children && (
          <div
            className={cn(
              "text-[12px] leading-[1.5] text-text-muted",
              title && "mt-0.5",
            )}
          >
            {children}
          </div>
        )}
        {action && <div className="mt-2.5 flex flex-wrap items-center gap-2">{action}</div>}
      </div>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          aria-label={dismissLabel}
          className="-mr-1 -mt-1 shrink-0 rounded-sm p-1 text-text-dim outline-none transition-colors hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
        >
          <X size={13} />
        </button>
      )}
    </div>
  );
}
