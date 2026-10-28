"use client";

import { useTheme } from "next-themes";
import { Moon, Sun } from "lucide-react";
import { useSyncExternalStore } from "react";
import { motion } from "framer-motion";

// Hook React 19 compliant : détecte le montage client sans useEffect+setState
function useMounted() {
  return useSyncExternalStore(
    () => () => {}, // subscribe (vide, pas besoin de souscription)
    () => true,     // getSnapshot côté client
    () => false     // getServerSnapshot côté serveur (SSR)
  );
}

export function ThemeToggle({ label }: { label: string }) {
  const { resolvedTheme, setTheme } = useTheme();
  const mounted = useMounted();

  if (!mounted) return <div className="h-10 w-10" aria-hidden />;

  const isDark = resolvedTheme === "dark";

  return (
    <motion.button
      type="button"
      aria-label={label}
      whileTap={{ scale: 0.92 }}
      whileHover={{ scale: 1.05 }}
      onClick={() => setTheme(isDark ? "light" : "dark")}
      className="flex h-10 w-10 items-center justify-center rounded-full border border-border bg-surface shadow-soft"
    >
      {isDark ? (
        <Sun className="h-5 w-5 text-warning" />
      ) : (
        <Moon className="h-5 w-5 text-primary" />
      )}
    </motion.button>
  );
}