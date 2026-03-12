import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = process.env.YOUTRACK_BASE_URL;
const TOKEN = process.env.YOUTRACK_TOKEN;

if (!BASE_URL || !TOKEN) {
  console.error(
    "Missing required environment variables: YOUTRACK_BASE_URL and YOUTRACK_TOKEN"
  );
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${TOKEN}`,
  Accept: "application/json",
  "Content-Type": "application/json",
};

async function youtrackFetch(
  path: string,
  options?: RequestInit
): Promise<unknown> {
  const url = `${BASE_URL}/api${path}`;
  const response = await fetch(url, {
    ...options,
    headers: { ...headers, ...options?.headers },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `YouTrack API error: ${response.status} ${response.statusText}\n${body}`
    );
  }

  const contentType = response.headers.get("content-type");
  if (contentType?.includes("application/json")) {
    return response.json();
  }
  return response.text();
}

const server = new McpServer({
  name: "youtrack",
  version: "1.0.0",
});

// Tool: List tickets matching a query
server.tool(
  "youtrack_list_tickets",
  "List YouTrack tickets matching a search query",
  {
    query: z.string().describe("YouTrack search query (e.g., 'State: Open tag: nloop')"),
    project: z.string().optional().describe("Filter by project short name"),
    limit: z.number().default(20).describe("Maximum number of results"),
  },
  async ({ query, project, limit }) => {
    const projectFilter = project ? ` project: ${project}` : "";
    const fullQuery = encodeURIComponent(`${query}${projectFilter}`);
    const fields =
      "id,idReadable,summary,description,created,updated,resolved,tags(name),priority(name),project(shortName),customFields(name,value(name))";

    const issues = await youtrackFetch(
      `/issues?query=${fullQuery}&fields=${fields}&$top=${limit}`
    );

    return {
      content: [{ type: "text" as const, text: JSON.stringify(issues, null, 2) }],
    };
  }
);

// Tool: Get ticket details
server.tool(
  "youtrack_get_ticket",
  "Get detailed information about a specific YouTrack ticket",
  {
    ticket_id: z.string().describe("Ticket ID (e.g., PROJ-123)"),
  },
  async ({ ticket_id }) => {
    const fields =
      "id,idReadable,summary,description,created,updated,resolved,tags(name),priority(name),project(shortName),reporter(login,fullName),assignee(login,fullName),customFields(name,value(name)),comments(text,author(login),created)";

    const issue = await youtrackFetch(
      `/issues/${ticket_id}?fields=${fields}`
    );

    return {
      content: [{ type: "text" as const, text: JSON.stringify(issue, null, 2) }],
    };
  }
);

// Tool: Update ticket status
server.tool(
  "youtrack_update_status",
  "Update the status/state of a YouTrack ticket",
  {
    ticket_id: z.string().describe("Ticket ID (e.g., PROJ-123)"),
    status: z.string().describe("New status value (e.g., 'In Progress', 'Done', 'Review')"),
  },
  async ({ ticket_id, status }) => {
    await youtrackFetch(`/issues/${ticket_id}`, {
      method: "POST",
      body: JSON.stringify({
        customFields: [
          {
            name: "State",
            $type: "StateIssueCustomField",
            value: { name: status },
          },
        ],
      }),
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `Ticket ${ticket_id} status updated to "${status}"`,
        },
      ],
    };
  }
);

// Tool: Add comment to ticket
server.tool(
  "youtrack_add_comment",
  "Add a comment to a YouTrack ticket",
  {
    ticket_id: z.string().describe("Ticket ID (e.g., PROJ-123)"),
    comment: z.string().describe("Comment text (supports YouTrack markdown)"),
  },
  async ({ ticket_id, comment }) => {
    await youtrackFetch(`/issues/${ticket_id}/comments`, {
      method: "POST",
      body: JSON.stringify({ text: comment }),
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `Comment added to ${ticket_id}`,
        },
      ],
    };
  }
);

// Tool: Get ticket comments
server.tool(
  "youtrack_get_comments",
  "Get all comments on a YouTrack ticket",
  {
    ticket_id: z.string().describe("Ticket ID (e.g., PROJ-123)"),
  },
  async ({ ticket_id }) => {
    const fields = "id,text,author(login,fullName),created,updated";
    const comments = await youtrackFetch(
      `/issues/${ticket_id}/comments?fields=${fields}`
    );

    return {
      content: [{ type: "text" as const, text: JSON.stringify(comments, null, 2) }],
    };
  }
);

// Tool: Update a custom field
server.tool(
  "youtrack_update_field",
  "Update a custom field on a YouTrack ticket",
  {
    ticket_id: z.string().describe("Ticket ID (e.g., PROJ-123)"),
    field: z.string().describe("Custom field name (e.g., 'Priority', 'Assignee', 'Type')"),
    value: z.string().describe("New value for the field"),
  },
  async ({ ticket_id, field, value }) => {
    await youtrackFetch(`/issues/${ticket_id}`, {
      method: "POST",
      body: JSON.stringify({
        customFields: [
          {
            name: field,
            value: { name: value },
          },
        ],
      }),
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `Field "${field}" updated to "${value}" on ${ticket_id}`,
        },
      ],
    };
  }
);

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
