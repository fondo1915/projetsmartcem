import { notFound } from "next/navigation";
import { Brain, Route, Sparkles, Trophy } from "lucide-react";
import { isLocale } from "@/i18n/config";
import { getDictionary } from "@/i18n/get-dictionary";
import { ThemeToggle } from "@/components/theme-toggle";
import { LocaleSwitcher } from "@/components/locale-switcher";
import { Cemo } from "@/components/cemo";
import { FeatureCard, HeroActions } from "@/components/home-client";

export default async function Home({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const t = await getDictionary(locale);

  // Les icônes sont rendues ICI (Server Component) et passées comme JSX déjà construit.
  const features = [
    { icon: <Brain className="h-9 w-9 text-primary" />, ...t.features.diagnostic },
    { icon: <Route className="h-9 w-9 text-secondary" />, ...t.features.adaptive },
    { icon: <Sparkles className="h-9 w-9 text-success" />, ...t.features.correction },
    { icon: <Trophy className="h-9 w-9 text-warning" />, ...t.features.bem },
  ];

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-16 px-5 py-6 sm:px-8">
      <header className="flex items-center justify-between">
        <div className="text-2xl font-extrabold tracking-tight">
          SMART<span className="text-primary">CEM</span>
        </div>
        <div className="flex items-center gap-3">
          <LocaleSwitcher current={locale} />
          <ThemeToggle label={t.ui.theme} />
        </div>
      </header>

      <section className="grid items-center gap-10 md:grid-cols-2">
        <div className="flex flex-col gap-6">
          <span className="w-fit rounded-full bg-primary/10 px-4 py-1.5 text-sm font-bold text-primary">{t.app.tagline}</span>
          <h1 className="text-4xl font-extrabold leading-tight sm:text-5xl">{t.hero.title}</h1>
          <p className="text-lg text-muted">{t.hero.subtitle}</p>
          <HeroActions
            primary={t.hero.cta}
            secondary={t.hero.secondary}
            primaryHref={`/${locale}/register`}
          />
        </div>
        <div className="flex flex-col items-center gap-4">
          <Cemo className="w-56 sm:w-72" />
          <p className="rounded-card bg-surface px-5 py-3 text-center font-semibold shadow-soft">{t.cemo.greeting}</p>
        </div>
      </section>

      <section className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {features.map((f, i) => (
          <FeatureCard key={f.title} index={i} title={f.title} desc={f.desc} icon={f.icon} />
        ))}
      </section>
    </main>
  );
}