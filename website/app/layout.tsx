import type { Metadata, Viewport } from "next";
import "./styles/fonts.css";
import "./styles/site.css";
import "./styles/voicey.css";
import "./styles/utilities.css";

const TITLE = "voicey: talk instead of typing, anywhere on your mac";
const DESCRIPTION =
  "dictate into any mac app. press a key, talk, and voicey types the polished text where your cursor is. your voice stays on your mac. free and open source.";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: TITLE,
  description: DESCRIPTION,
  openGraph: { title: TITLE, description: DESCRIPTION, type: "website", siteName: "voicey" },
  twitter: { card: "summary_large_image", title: TITLE, description: DESCRIPTION },
};

export const viewport: Viewport = { themeColor: "#f5f5f5" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="inter_5901b7c6-module__ec5Qua__variable">
      <body>{children}</body>
    </html>
  );
}
