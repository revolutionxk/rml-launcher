import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface CardRootProps {
  children: ReactNode;
  className?: string;
  highlighted?: boolean;
}

function CardRoot({ children, className, highlighted }: CardRootProps) {
  return (
    <div
      className={cn(
        "bg-card border border-border rounded-sm overflow-hidden",
        "shadow-[var(--card-shadow)]",
        "transition-[border-color,background] duration-200",
        className,
      )}
      style={highlighted ? {
        borderColor: "color-mix(in srgb, var(--color-accent) 28%, transparent)",
        backgroundColor: "color-mix(in srgb, var(--color-accent) 4%, transparent)",
      } : undefined}
    >
      {children}
    </div>
  );
}
CardRoot.displayName = "Card.Root";

interface CardHeaderProps {
  children: ReactNode;
  className?: string;
  border?: boolean;
}

function CardHeader({ children, className, border = true }: CardHeaderProps) {
  return (
    <div
      className={cn(
        "card-header px-4.5 pt-3.5 pb-3",
        border && "border-b border-border-subtle",
        className,
      )}
    >
      {children}
    </div>
  );
}
CardHeader.displayName = "Card.Header";

function CardLabel({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={cn(
        "text-xs font-semibold uppercase tracking-[0.07em] text-text-muted",
        className,
      )}
    >
      {children}
    </div>
  );
}
CardLabel.displayName = "Card.Label";

function CardDescription({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("text-[11.5px] text-text-dim mt-1 leading-[1.45]", className)}>
      {children}
    </div>
  );
}
CardDescription.displayName = "Card.Description";

function CardBody({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("card-body p-[14px_18px]", className)}>{children}</div>;
}
CardBody.displayName = "Card.Body";

function CardSeparator({ className }: { className?: string }) {
  return <div className={cn("h-px bg-border-subtle", className)} />;
}
CardSeparator.displayName = "Card.Separator";

export const Card = {
  Root: CardRoot,
  Header: CardHeader,
  Label: CardLabel,
  Description: CardDescription,
  Body: CardBody,
  Separator: CardSeparator,
};
