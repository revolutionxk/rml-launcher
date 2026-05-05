import { motion, type HTMLMotionProps } from "motion/react";
import { createContext, forwardRef, type ReactNode } from "react";

import { cn } from "@/lib/utils";

type ButtonVariant = "primary" | "ghost" | "danger";
type ButtonSize = "sm" | "md" | "icon";

interface ButtonContextValue {
  variant: ButtonVariant;
  size: ButtonSize;
}

const ButtonContext = createContext<ButtonContextValue>({ variant: "ghost", size: "md" });

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    "bg-accent text-white border-accent hover:bg-accent-hover hover:border-accent-hover active:opacity-90",
  ghost:
    "bg-transparent text-text-muted border-border hover:bg-surface-2 hover:text-text hover:border-[#333]",
  danger: "bg-transparent text-red border-transparent hover:bg-red-muted",
};

const sizeClasses: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-[11.5px] gap-1.5",
  md: "px-3.5 py-[7px] text-[12.5px] gap-1.75",
  icon: "p-[7px]",
};

export interface ButtonRootProps extends Omit<HTMLMotionProps<"button">, "type"> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  type?: "button" | "submit" | "reset";
}

const ButtonRoot = forwardRef<HTMLButtonElement, ButtonRootProps>(
  ({ variant = "ghost", size = "md", className, children, type = "button", ...props }, ref) => {
    return (
      <ButtonContext.Provider value={{ variant, size }}>
        <motion.button
          ref={ref}
          type={type}
          className={cn(
            "inline-flex items-center justify-center rounded-sm",
            "font-semibold cursor-pointer border leading-none",
            "transition-[background,border-color,color,opacity] duration-150",
            "disabled:opacity-45 disabled:cursor-not-allowed",
            "outline-none focus-visible:ring-2 focus-visible:ring-accent/40",
            variantClasses[variant],
            sizeClasses[size],
            className,
          )}
          whileTap={{ scale: 0.965 }}
          transition={{ type: "spring", stiffness: 400, damping: 28 }}
          {...props}
        >
          {children}
        </motion.button>
      </ButtonContext.Provider>
    );
  },
);
ButtonRoot.displayName = "Button.Root";

function ButtonIcon({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        "flex items-center justify-center shrink-0 [&_svg]:pointer-events-none",
        className,
      )}
    >
      {children}
    </span>
  );
}
ButtonIcon.displayName = "Button.Icon";

function ButtonLabel({ children, className }: { children: ReactNode; className?: string }) {
  return <span className={cn(className)}>{children}</span>;
}
ButtonLabel.displayName = "Button.Label";

export const Button = {
  Root: ButtonRoot,
  Icon: ButtonIcon,
  Label: ButtonLabel,
};
