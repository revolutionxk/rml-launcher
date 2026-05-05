import { animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type RefObject,
  type ReactNode,
} from "react";

import { cn } from "@/lib/utils";

const TRAVEL = 16;
const THUMB_SIZE = 14;
const THUMB_PAD = 2;
const DRAG_THRESHOLD = 4;

const spring = { type: "spring" as const, stiffness: 520, damping: 34, mass: 0.5 };

interface SwitchContextValue {
  checked: boolean;
  disabled: boolean;
  onCheckedChange: (v: boolean) => void;
  thumbHandled: RefObject<boolean>;
  thumbX: MotionValue<number>;
}

const SwitchContext = createContext<SwitchContextValue>({
  checked: false,
  disabled: false,
  onCheckedChange: () => {},
  thumbHandled: { current: false },
  thumbX: null as unknown as MotionValue<number>,
});

interface SwitchRootProps {
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  disabled?: boolean;
  className?: string;
  children?: ReactNode;
  "aria-label"?: string;
  id?: string;
}

function SwitchRoot({
  checked,
  onCheckedChange,
  disabled = false,
  className,
  children,
  "aria-label": ariaLabel,
  id,
}: SwitchRootProps) {
  const thumbHandled = useRef(false);
  const thumbX = useMotionValue(checked ? TRAVEL : 0);
  const fillOpacity = useTransform(thumbX, [0, TRAVEL], [0, 1]);

  return (
    <SwitchContext.Provider value={{ checked, disabled, onCheckedChange, thumbHandled, thumbX }}>
      <button
        id={id}
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => {
          if (thumbHandled.current || disabled) return;
          onCheckedChange(!checked);
        }}
        onKeyDown={(e) => {
          if ((e.key === " " || e.key === "Enter") && !disabled) {
            e.preventDefault();
            onCheckedChange(!checked);
          }
        }}
        className={cn(
          "relative inline-flex shrink-0 rounded-full outline-none select-none overflow-hidden",
          "w-9 h-5",
          "bg-surface border border-border",
          "transition-[border-color] duration-200",
          checked && "border-accent",
          "focus-visible:ring-2 focus-visible:ring-accent/40 focus-visible:ring-offset-1 focus-visible:ring-offset-bg",
          disabled ? "opacity-45 cursor-not-allowed" : "cursor-pointer",
          className,
        )}
        aria-label={ariaLabel}
      >
        <motion.span
          className="absolute inset-0 bg-accent pointer-events-none"
          style={{ opacity: fillOpacity }}
        />
        {children}
      </button>
    </SwitchContext.Provider>
  );
}
SwitchRoot.displayName = "Switch.Root";

function SwitchThumb({ className }: { className?: string }) {
  const { checked, disabled, onCheckedChange, thumbHandled, thumbX } = useContext(SwitchContext);

  const [isActive, setIsActive] = useState(false);
  const spanRef = useRef<HTMLSpanElement>(null);
  const startClientX = useRef(0);
  const startX = useRef(0);
  const isDragging = useRef(false);

  useEffect(() => {
    animate(thumbX, checked ? TRAVEL : 0, spring);
  }, [checked, thumbX]);

  function onPointerDown(e: React.PointerEvent<HTMLSpanElement>) {
    if (disabled) return;
    e.preventDefault();
    e.stopPropagation();
    spanRef.current?.setPointerCapture(e.pointerId);
    startClientX.current = e.clientX;
    startX.current = thumbX.get();
    isDragging.current = false;
    setIsActive(true);
  }

  function onPointerMove(e: React.PointerEvent<HTMLSpanElement>) {
    if (!isActive) return;
    const delta = e.clientX - startClientX.current;
    if (Math.abs(delta) > DRAG_THRESHOLD) isDragging.current = true;
    if (!isDragging.current) return;
    thumbX.set(Math.min(TRAVEL, Math.max(0, startX.current + delta)));
  }

  function onPointerUp(e: React.PointerEvent<HTMLSpanElement>) {
    if (!isActive) return;
    e.stopPropagation();
    setIsActive(false);

    thumbHandled.current = true;
    setTimeout(() => {
      thumbHandled.current = false;
    }, 80);

    if (!isDragging.current) {
      const next = !checked;
      animate(thumbX, next ? TRAVEL : 0, spring);
      onCheckedChange(next);
    } else {
      const shouldBeChecked = thumbX.get() > TRAVEL / 2;
      animate(thumbX, shouldBeChecked ? TRAVEL : 0, spring);
      if (shouldBeChecked !== checked) onCheckedChange(shouldBeChecked);
    }
  }

  function onPointerCancel() {
    setIsActive(false);
    isDragging.current = false;
    animate(thumbX, checked ? TRAVEL : 0, spring);
  }

  return (
    <motion.span
      ref={spanRef}
      style={{
        x: thumbX,
        top: THUMB_PAD,
        height: THUMB_SIZE,
        left: THUMB_PAD,
      }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerCancel}
      className={cn(
        "absolute rounded-full bg-white",
        "shadow-[0_1px_2px_rgba(0,0,0,0.28)]",
        "touch-none z-10 select-none",
        "transition-[width] duration-100",
        isActive ? "w-[18px]" : "w-[14px]",
        className,
      )}
    />
  );
}
SwitchThumb.displayName = "Switch.Thumb";

export const Switch = {
  Root: SwitchRoot,
  Thumb: SwitchThumb,
};
