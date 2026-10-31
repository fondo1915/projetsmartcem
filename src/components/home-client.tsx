"use client";

import { motion } from "framer-motion";
import type { ReactNode } from "react";
import Link from "next/link";

export function HeroActions({
  primary,
  secondary,
  primaryHref,
}: { primary: string; secondary: string; primaryHref: string }) {
  return (
    <div className="flex flex-wrap gap-3">
      <motion.div whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.96 }}>
        <Link
          href={primaryHref}
          className="block rounded-btn bg-primary px-6 py-3.5 text-base font-extrabold text-primary-foreground shadow-soft"
        >
          {primary}
        </Link>
      </motion.div>
      <motion.button
        whileHover={{ scale: 1.03 }}
        whileTap={{ scale: 0.96 }}
        className="rounded-btn border border-border bg-surface px-6 py-3.5 text-base font-bold"
      >
        {secondary}
      </motion.button>
    </div>
  );
}

export function FeatureCard({
  index, title, desc, icon,
}: { index: number; title: string; desc: string; icon: ReactNode }) {
  return (
    <motion.article
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay: index * 0.08, type: "spring", stiffness: 120 }}
      whileHover={{ y: -4 }}
      className="flex flex-col gap-3 rounded-card border border-border bg-surface p-6 shadow-soft"
    >
      {icon}
      <h2 className="text-lg font-extrabold">{title}</h2>
      <p className="text-sm text-muted">{desc}</p>
    </motion.article>
  );
}