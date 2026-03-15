import { createServer } from "http";

// In-memory database simulation
const db = {
  query: (sql: string) => {
    console.log("Executing:", sql);
    return [{ id: 1, name: "Alice", email: "alice@example.com", password: "secret123" }];
  },
};

const server = createServer(async (req, res) => {
  const url = new URL(req.url!, `http://${req.headers.host}`);

  // GET /users?name=...
  if (url.pathname === "/users" && req.method === "GET") {
    const name = url.searchParams.get("name");
    try {
      // BUG: SQL Injection - user input directly concatenated
      const users = db.query(`SELECT * FROM users WHERE name = '${name}'`);
      res.writeHead(200, { "Content-Type": "application/json" });
      // BUG: Exposing password field in response
      res.end(JSON.stringify(users));
    } catch (err: any) {
      // BUG: Leaking stack trace to client
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: err.message, stack: err.stack }));
    }
    return;
  }

  // POST /users
  if (url.pathname === "/users" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      const data = JSON.parse(body);
      // BUG: No input validation
      db.query(
        `INSERT INTO users (name, email, password) VALUES ('${data.name}', '${data.email}', '${data.password}')`
      );
      res.writeHead(200);
      res.end("OK");
    });
    return;
  }

  // POST /admin/delete-all
  if (url.pathname === "/admin/delete-all" && req.method === "POST") {
    // BUG: No authentication check for admin endpoint
    db.query("DELETE FROM users");
    res.writeHead(200);
    res.end("All users deleted");
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

// BUG: Magic number, no configuration
server.listen(3000);
console.log("Server running");
