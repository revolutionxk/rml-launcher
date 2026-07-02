import { ChevronRight } from "lucide-react";
import { motion } from "motion/react";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface ActionButtonRootProps {
  onClick?: () => void;
  disabled?: boolean;
  className?: string;
  children: ReactNode;
}

function ActionButtonRoot({ onClick, disabled, className, children }: ActionButtonRootProps) {
  return (
    <motion.button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={cn(
        "group flex items-center gap-3.5 px-4.5 py-4",
        "bg-card border border-border rounded-sm",
        "cursor-pointer text-left w-full relative overflow-hidden",
        "transition-[border-color,background,box-shadow] duration-200",
        "hover:bg-card-hover hover:border-border-focus",
        "active:bg-surface-2",
        "outline-none focus-visible:ring-2 focus-visible:ring-accent/40",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        className,
      )}
      whileTap={{ scale: 0.985 }}
      transition={{ type: "spring", stiffness: 400, damping: 28 }}
    >
      {children}
    </motion.button>
  );
}
ActionButtonRoot.displayName = "ActionButton.Root";

function ActionButtonIcon({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "w-9 h-9 rounded-sm flex items-center justify-center shrink-0",
        "[&_svg]:pointer-events-none",
        className,
      )}
    >
      {children}
    </div>
  );
}
ActionButtonIcon.displayName = "ActionButton.Icon";

function ActionButtonContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex-1 min-w-0", className)}>{children}</div>;
}
ActionButtonContent.displayName = "ActionButton.Content";

function ActionButtonLabel({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("text-[13.5px] font-semibold text-text leading-[1.3]", className)}>
      {children}
    </div>
  );
}
ActionButtonLabel.displayName = "ActionButton.Label";

function ActionButtonDescription({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("text-[11.5px] text-text-muted mt-0.5", className)}>
      {children}
    </div>
  );
}
ActionButtonDescription.displayName = "ActionButton.Description";

function ActionButtonArrow({ className }: { className?: string }) {
  return (
    <ChevronRight
      size={16}
      className={cn(
        "shrink-0 text-text-dim",
        "transition-[transform,color] duration-200",
        "group-hover:translate-x-0.75 group-hover:text-accent",
        className,
      )}
    />
  );
}
ActionButtonArrow.displayName = "ActionButton.Arrow";

export const ActionButton = {
  Root: ActionButtonRoot,
  Icon: ActionButtonIcon,
  Content: ActionButtonContent,
  Label: ActionButtonLabel,
  Description: ActionButtonDescription,
  Arrow: ActionButtonArrow,
};
