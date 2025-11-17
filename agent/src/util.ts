interface Config {
  model: string | undefined;
  temperature: number;
  maxTokens: number;
  tools: string[];
}

function readConfigFromEnv() {
  const config = {
    model: process.env.AGENT_MODEL,
    temperature: parseFloat(process.env.AGENT_TEMPERATURE || "0.0"),
    maxTokens: parseInt(process.env.AGENT_MAX_TOKENS || "2048", 10),
    tools: (process.env.AGENT_TOOLS || "").split(","),
    metricsEndpoint: process.env.METRICS_ENDPOINT,
  };

  return config;
}

async function getPromMetrics(query: string): Promise<any> {
  if (!config.metricsEndpoint) {
    throw new Error("Metrics endpoint is not configured");
  }

  const url = new URL("/api/v1/query", config.metricsEndpoint);
  url.searchParams.append("query", query);

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Failed to fetch metrics: ${response.statusText}`);
  }

  const data = await response.json();
  return data;
}

const config = readConfigFromEnv();

export { Config, readConfigFromEnv, getPromMetrics, config };