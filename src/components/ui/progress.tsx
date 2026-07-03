import { Progress as BaseProgress } from "@base-ui/react/progress";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface ProgressRootProps {
  value: number | null;
  min?: number;
  max?: number;
  className?: string;
  children: ReactNode;
  "aria-label"?: string;
}

function ProgressRoot({ value, min, max, className, children, "aria-label": ariaLabel }: ProgressRootProps) {
  return (
    <BaseProgress.Root
      value={value}
      min={min}
      max={max}
      aria-label={ariaLabel}
      className={cn("w-full", className)}
    >
      {children}
    </BaseProgress.Root>
  );
}
ProgressRoot.displayName = "Progress.Root";

function ProgressTrack({ className, children }: { className?: string; children?: ReactNode }) {
  return (
    <BaseProgress.Track
      className={cn(
        "h-[3px] bg-border rounded-full overflow-hidden w-full",
        className,
      )}
    >
      {children}
    </BaseProgress.Track>
  );
}
ProgressTrack.displayName = "Progress.Track";

function ProgressIndicator({ className }: { className?: string }) {
  return (
    <BaseProgress.Indicator
      className={cn(
        "h-full bg-accent rounded-full",
        "transition-[width] duration-500 ease-out",
        "data-[indeterminate]:animate-progress-indeterminate",
        className,
      )}
    />
  );
}
ProgressIndicator.displayName = "Progress.Indicator";

export const Progress = {
  Root: ProgressRoot,
  Track: ProgressTrack,
  Indicator: ProgressIndicator,
};
