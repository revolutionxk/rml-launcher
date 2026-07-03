import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface EmptyStateProps {
  icon?: ReactNode;
  iconClass?: string;
  title: ReactNode;
  description?: ReactNode;
  action?: ReactNode;
  compact?: boolean;
  className?: string;
}

export function EmptyState({
  icon,
  iconClass = "icon-box--blue",
  title,
  description,
  action,
  compact,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-3 rounded-lg border border-border bg-card text-center shadow-(--card-shadow)",
        compact ? "px-5 py-9" : "px-6 py-14",
        className,
      )}
    >
      {icon && (
        <div
          className={cn(
            "flex items-center justify-center rounded-lg",
            compact ? "h-11 w-11" : "h-14 w-14",
            iconClass,
          )}
        >
          {icon}
        </div>
      )}
      <div className="flex flex-col gap-1.5">
        <div className="text-[14px] font-semibold text-text">{title}</div>
        {description && (
          <div className="mx-auto max-w-xs text-[12px] leading-relaxed text-text-muted">
            {description}
          </div>
        )}
      </div>
      {action && <div className="mt-1">{action}</div>}
    </div>
  );
}
