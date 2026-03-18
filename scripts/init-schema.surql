-- AgentDB Schema Definition
-- Namespace: agents
-- Databases: logs (ephemeral), knowledge (persistent)

-- ============================================================
-- DB: logs (ephemeral, TTL 14d managed externally)
-- ============================================================
USE NS agents DB logs;

DEFINE TABLE event SCHEMALESS;

DEFINE FIELD agent      ON TABLE event TYPE string;
DEFINE FIELD type       ON TABLE event TYPE string;
DEFINE FIELD data       ON TABLE event TYPE object FLEXIBLE;
DEFINE FIELD tags       ON TABLE event TYPE option<array<string>>;
DEFINE FIELD created_at ON TABLE event TYPE datetime DEFAULT time::now();

DEFINE INDEX idx_event_agent ON TABLE event COLUMNS agent;
DEFINE INDEX idx_event_type  ON TABLE event COLUMNS type;
DEFINE INDEX idx_event_time  ON TABLE event COLUMNS created_at;

-- ============================================================
-- DB: knowledge (persistent)
-- ============================================================
USE NS agents DB knowledge;

DEFINE TABLE entry SCHEMALESS;

DEFINE FIELD agent      ON TABLE entry TYPE string;
DEFINE FIELD kind       ON TABLE entry TYPE string;
DEFINE FIELD domain     ON TABLE entry TYPE option<string>;
DEFINE FIELD title      ON TABLE entry TYPE string;
DEFINE FIELD body       ON TABLE entry TYPE string;
DEFINE FIELD data       ON TABLE entry TYPE object FLEXIBLE;
DEFINE FIELD tags       ON TABLE entry TYPE option<array<string>>;
DEFINE FIELD created_at ON TABLE entry TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE entry TYPE datetime DEFAULT time::now();

DEFINE INDEX idx_entry_agent  ON TABLE entry COLUMNS agent;
DEFINE INDEX idx_entry_kind   ON TABLE entry COLUMNS kind;
DEFINE INDEX idx_entry_domain ON TABLE entry COLUMNS domain;

DEFINE TABLE relates_to SCHEMALESS;

DEFINE FIELD relation   ON TABLE relates_to TYPE string;
DEFINE FIELD created_at ON TABLE relates_to TYPE datetime DEFAULT time::now();
