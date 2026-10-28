"use client";

import { motion } from "framer-motion";

export function Cemo({ className = "" }: { className?: string }) {
  return (
    <motion.svg
      viewBox="0 0 200 200"
      className={className}
      role="img"
      aria-label="CEMO"
      animate={{ y: [0, -8, 0] }}
      transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
    >
      <ellipse cx="100" cy="120" rx="60" ry="65" fill="#8b5cf6" />
      <ellipse cx="100" cy="135" rx="38" ry="42" fill="#c4b5fd" />
      <circle cx="78" cy="95" r="20" fill="#fff" />
      <circle cx="122" cy="95" r="20" fill="#fff" />
      <circle cx="80" cy="97" r="9" fill="#0f172a" />
      <circle cx="120" cy="97" r="9" fill="#0f172a" />
      <circle cx="83" cy="94" r="3" fill="#fff" />
      <circle cx="123" cy="94" r="3" fill="#fff" />
      <polygon points="100,108 92,120 108,120" fill="#f59e0b" />
      {/* Chapeau de diplômé */}
      <polygon points="45,70 100,48 155,70 100,92" fill="#0f172a" />
      <rect x="96" y="56" width="8" height="30" fill="#10b981" />
      <circle cx="100" cy="88" r="5" fill="#f59e0b" />
    </motion.svg>
  );
}