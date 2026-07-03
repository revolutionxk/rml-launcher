import { motion } from "motion/react";
import { type ReactNode, useId } from "react";

import { cn } from "@/lib/utils";

export interface TabItem<T extends string> {
  value: T;
  label: string;
  icon?: ReactNode;
}

interface TabsProps<T extends string> {
  value: T;
  onValueChange: (value: T) => void;
  tabs: TabItem<T>[];
  className?: string;
}

export function Tabs<T extends string>({ value, onValueChange, tabs, className }: TabsProps<T>) {
  const layoutId = useId();

  return (
    <div className={cn("flex items-center gap-0.5 border-b border-border-subtle", className)}>
      {tabs.map((tab) => {
        const active = tab.value === value;
        return (
          <button
            key={tab.value}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onValueChange(tab.value)}
            className={cn(
              "relative flex items-center gap-2 px-3.5 py-2.5 text-[12.5px] font-medium",
              "cursor-default outline-none transition-colors duration-150",
              "focus-visible:ring-2 focus-visible:ring-accent/40 focus-visible:rounded-t",
              "[&_svg]:h-3.5 [&_svg]:w-3.5 [&_svg]:shrink-0",
              active ? "text-accent" : "text-text-muted hover:text-text",
            )}
          >
            {tab.icon}
            {tab.label}
            {active && (
              <motion.div
                layoutId={`${layoutId}-underline`}
                className="absolute inset-x-0 -bottom-px h-0.5 rounded-full bg-accent"
                transition={{ type: "spring", stiffness: 500, damping: 40, mass: 0.8 }}
              />
            )}
          </button>
        );
      })}
    </div>
  );
}
