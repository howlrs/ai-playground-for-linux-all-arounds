export default function Home() {
  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>AI Playground - Next.js Example</h1>
      <p>このプロジェクトは AI Playground 環境のテンプレートです。</p>
      <h2>使い方</h2>
      <pre style={{ background: "#f4f4f4", padding: "1rem" }}>
        {`# コンテナ内で
cd ~/workspace
cp -r ~/examples/projects/nextjs-app ./my-app
cd my-app
npm install
npm run dev

# Claude Code に依頼
claude
> "このアプリにダッシュボード機能を追加して"`}
      </pre>
    </main>
  );
}
