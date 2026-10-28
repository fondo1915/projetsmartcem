import { notFound } from "next/navigation";
import { ThemeProvider } from "@/components/theme-provider";
import { HtmlAttrs } from "@/components/html-attrs";
import { isLocale, locales } from "@/i18n/config";

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();

  return (
    <ThemeProvider>
      <HtmlAttrs locale={locale} />
      {children}
    </ThemeProvider>
  );
}