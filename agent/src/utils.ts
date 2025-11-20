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

const config = readConfigFromEnv();

export { Config, readConfigFromEnv, config };