const http = require("http");

const port = Number(process.env.PORT || 4096);

const server = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/api/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ status: "UP", service: "flowstudy-opencode-runtime" }));
    return;
  }

  res.writeHead(501, { "content-type": "application/json" });
  res.end(JSON.stringify({
    code: "OPENCODE_RUNTIME_PLACEHOLDER",
    message: "OpenCode runtime image is available, but AI execution is not enabled yet."
  }));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`flowstudy-opencode-runtime listening on ${port}`);
});

