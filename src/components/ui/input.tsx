import { forwardRef, type InputHTMLAttributes } from "react";

import { cn } from "@/lib/utils";

interface InputRootProps {
  className?: string;
  children?: React.ReactNode;
}

function InputRoot({ className, children }: InputRootProps) {
  return <div className={cn("relative w-full", className)}>{children}</div>;
}
InputRoot.displayName = "Input.Root";

function InputIcon({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        "absolute left-2.5 top-1/2 -translate-y-1/2",
        "text-text-dim pointer-events-none",
        "[&_svg]:w-[13px] [&_svg]:h-[13px]",
        className,
      )}
    >
      {children}
    </span>
  );
}
InputIcon.displayName = "Input.Icon";

interface InputFieldProps extends InputHTMLAttributes<HTMLInputElement> {
  hasLeadingIcon?: boolean;
  className?: string;
}

const InputField = forwardRef<HTMLInputElement, InputFieldProps>(
  ({ hasLeadingIcon, className, ...props }, ref) => {
    return (
      <input
        ref={ref}
        className={cn(
          "w-full bg-surface border border-border rounded-sm",
          "text-[13px] text-text font-[inherit]",
          "px-[11px] py-[7px]",
          "outline-none transition-[border-color,box-shadow] duration-200",
          "placeholder:text-text-dim",
          "focus:border-border-focus focus:ring-2 focus:ring-accent/20",
          hasLeadingIcon && "pl-8",
          className,
        )}
        {...props}
      />
    );
  },
);
InputField.displayName = "Input.Field";

export const Input = {
  Root: InputRoot,
  Icon: InputIcon,
  Field: InputField,
};
