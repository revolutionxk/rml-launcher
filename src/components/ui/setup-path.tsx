import { Check, Lock } from "lucide-react";
import { motion } from "motion/react";
import { type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export type SetupStepStatus = "done" | "current" | "locked";

export interface SetupStep {
  id: string;
  title: string;
  description: string;
  status: SetupStepStatus;
  action?: {
    label: string;
    onClick: () => void;
    icon?: ReactNode;
    loading?: boolean;
    disabled?: boolean;
  };
  secondaryAction?: {
    label: string;
    onClick: () => void;
    icon?: ReactNode;
  };
  hint?: ReactNode;
}

function StepNode({ status, index }: { status: SetupStepStatus; index: number }) {
  if (status === "done") {
    return (
      <div className="flex h-7 w-7 items-center justify-center rounded-full bg-green text-white shadow-[0_0_0_4px_var(--color-green-muted)]">
        <Check size={14} strokeWidth={2.5} />
      </div>
    );
  }

  if (status === "current") {
    return (
      <div className="relative flex h-7 w-7 items-center justify-center rounded-full bg-accent text-white shadow-[0_0_0_4px_var(--color-accent-muted)]">
        <span className="text-[12px] font-bold tabular-nums">{index + 1}</span>
      </div>
    );
  }

  return (
    <div className="flex h-7 w-7 items-center justify-center rounded-full border border-border bg-surface text-text-dim">
      <Lock size={12} />
    </div>
  );
}

function StepRow({ step, index, isLast }: { step: SetupStep; index: number; isLast: boolean }) {
  const isCurrent = step.status === "current";
  const isLocked = step.status === "locked";

  return (
    <li className="relative flex gap-3.5">
      <div className="flex flex-col items-center">
        <StepNode status={step.status} index={index} />
        {!isLast && (
          <div
            className={cn(
              "mt-1 w-px flex-1",
              step.status === "done" ? "bg-green/40" : "bg-border",
            )}
          />
        )}
      </div>
      
      <div className={cn("min-w-0 flex-1", isLast ? "pb-0" : "pb-5")}>
        <div
          className={cn(
            "rounded-lg border px-4 py-3 transition-colors duration-200",
            isCurrent
              ? "border-accent/30 bg-accent-muted"
              : "border-transparent",
          )}
        >
          <div className="flex items-center gap-2">
            <span
              className={cn(
                "text-[13.5px] font-semibold tracking-[-0.01em]",
                isLocked ? "text-text-muted" : "text-text",
              )}
            >
              {step.title}
            </span>
            {step.status === "done" && (
              <span className="inline-flex items-center gap-1 text-[11px] font-medium text-green">
                <Check size={11} strokeWidth={2.5} />
                Done
              </span>
            )}
          </div>
          <p
            className={cn(
              "mt-1 text-[12px] leading-[1.5]",
              isLocked ? "text-text-dim" : "text-text-muted",
            )}
          >
            {step.description}
          </p>

          {isCurrent && step.action && (
            <div className="mt-3">
              <div className="flex flex-wrap items-center gap-x-1 gap-y-2">
                <Button.Root
                  variant="primary"
                  onClick={step.action.onClick}
                  disabled={step.action.disabled || step.action.loading}
                >
                  {step.action.icon && <Button.Icon>{step.action.icon}</Button.Icon>}
                  <Button.Label>{step.action.label}</Button.Label>
                </Button.Root>
                {step.secondaryAction && (
                  <Button.Root variant="ghost" onClick={step.secondaryAction.onClick}>
                    {step.secondaryAction.icon && (
                      <Button.Icon>{step.secondaryAction.icon}</Button.Icon>
                    )}
                    <Button.Label>{step.secondaryAction.label}</Button.Label>
                  </Button.Root>
                )}
              </div>
              {step.hint && (
                <div className="mt-2 text-[11.5px] text-text-muted">{step.hint}</div>
              )}
            </div>
          )}
        </div>
      </div>
    </li>
  );
}

export function SetupPath({ steps, className }: { steps: SetupStep[]; className?: string }) {
  return (
    <motion.ol
      className={cn("flex flex-col", className)}
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25, ease: [0.25, 0.1, 0.25, 1] }}
    >
      {steps.map((step, index) => (
        <StepRow
          key={step.id}
          step={step}
          index={index}
          isLast={index === steps.length - 1}
        />
      ))}
    </motion.ol>
  );
}
