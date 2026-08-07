import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://framelingo-dependency-graph.jsdream3.chatgpt.site"),
  title: "Framelingo Architecture Lab",
  description: "Explore package dependencies and trace the impact of a change across Framelingo.",
  openGraph: {
    title: "Framelingo Architecture Lab",
    description: "Trace the change before you make it.",
    images: [{ url: "/og.png", width: 1536, height: 1024 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Framelingo Architecture Lab",
    description: "Trace the change before you make it.",
    images: ["/og.png"],
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
