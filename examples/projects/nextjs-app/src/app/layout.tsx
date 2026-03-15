export const metadata = {
  title: "AI Playground - Next.js Example",
  description: "Next.js project template for AI Playground",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
