"use client";

// Adapted from educalvolpz/dynamic-island (21st.dev): the author's layout spring,
// per-transition bounce table and blur-in content swap are kept as-is; the demo
// views (weather, music, call) and the view switcher were removed so the island
// can host any content keyed by `view`.
import { motion, useReducedMotion } from "motion/react";
import { type ReactNode, useRef } from "react";

const BOUNCE_VARIANTS = {
  idle: 0.5,
  "ring-idle": 0.5,
  "timer-ring": 0.35,
  "ring-timer": 0.35,
  "timer-idle": 0.3,
  "idle-timer": 0.3,
  "idle-ring": 0.5,
} as const;

const DEFAULT_BOUNCE = 0.5;

export interface DynamicIslandProps {
  className?: string;
  view: string;
  children: ReactNode;
  onClick?: () => void;
}

export function DynamicIsland({ view, children, className = "", onClick }: DynamicIslandProps) {
  const shouldReduceMotion = useReducedMotion();
  const prev = useRef(view);
  const variantKey = `${prev.current}-${view}`;
  prev.current = view;
  const bounce = BOUNCE_VARIANTS[variantKey as keyof typeof BOUNCE_VARIANTS] ?? DEFAULT_BOUNCE;

  return (
    <motion.div
      className={`mx-auto w-fit min-w-[100px] overflow-hidden bg-black ${onClick ? "cursor-pointer" : ""} ${className}`}
      layout
      onClick={onClick}
      style={{ borderRadius: 32 }}
      transition={shouldReduceMotion ? { duration: 0 } : { type: "spring" as const, bounce, duration: 0.25 }}
    >
      <motion.div
        animate={
          shouldReduceMotion
            ? { scale: 1, opacity: 1 }
            : { scale: 1, opacity: 1, filter: "blur(0px)", originX: 0.5, originY: 0.5, transition: { delay: 0.05 } }
        }
        initial={{ scale: 0.9, opacity: 0, filter: "blur(5px)", originX: 0.5, originY: 0.5 }}
        key={view}
        transition={{ type: "spring" as const, bounce }}
      >
        {children}
      </motion.div>
    </motion.div>
  );
}
