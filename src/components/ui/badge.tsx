import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

type BadgeVariant = "blue" | "green" | "yellow" | "red" | "gray" | "purple";

const variantClasses: Record<BadgeVariant, string> = {
  blue: "bg-accent-muted text-accent",
  green: "bg-green-muted text-green",
  yellow: "bg-yellow-muted text-yellow",
  red: "bg-red-muted text-red",
  gray: "bg-white/5 text-text-muted",
  purple: "bg-[rgba(139,92,246,0.12)] text-[#a78bfa]",
};

interface BadgeRootProps {
  variant?: BadgeVariant;
  children: ReactNode;
  className?: string;
}

function BadgeRoot({ variant = "gray", children, className }: BadgeRootProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 px-[7px] py-[2px]",
        "rounded-full text-[10.5px] font-semibold leading-[1.4]",
        "[&_svg]:pointer-events-none",
        variantClasses[variant],
        className,
      )}
    >
      {children}
    </span>
  );
}
BadgeRoot.displayName = "Badge.Root";

function BadgeIcon({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <span className={cn("flex items-center justify-center shrink-0", className)}>{children}</span>
  );
}
BadgeIcon.displayName = "Badge.Icon";

function BadgeLabel({ children, className }: { children: ReactNode; className?: string }) {
  return <span className={cn(className)}>{children}</span>;
}
BadgeLabel.displayName = "Badge.Label";

export const Badge = {
  Root: BadgeRoot,
  Icon: BadgeIcon,
  Label: BadgeLabel,
};
