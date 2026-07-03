import { RefreshCw } from "lucide-react";

import { cn } from "@/lib/utils";

export function Spinner({ size = 14, className }: { size?: number; className?: string }) {
  return <RefreshCw size={size} className={cn("animate-spin", className)} aria-hidden />;
}

export function LoadingState({ label, className }: { label: string; className?: string }) {
  return (
    <div
      role="status"
      className={cn(
        "flex items-center justify-center gap-2.5 rounded-lg border border-border bg-card px-5 py-8 text-[12.5px] text-text-muted",
        className,
      )}
    >
      <Spinner />
      {label}
    </div>
  );
}
