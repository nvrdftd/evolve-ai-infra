import { StateGraph, START, END} from "@langchain/langgraph";
import { registry } from "@langchain/langgraph/zod";
import { BaseMessage, HumanMessage, SystemMessage } from "@langchain/core/messages";
import { ChatVertexAI } from "@langchain/google-vertexai";
import { z } from "zod";
import { config } from "./utils";
import { MetricsService } from "./services/metricsService";
import { knowledgeBaseService } from "./services/knowledgeBaseService";

const AgentState = z.object({
  messages: z.array(z.custom<BaseMessage>()).register(registry, {
    reducer: {
      fn: (x, y) => x.concat(y),
    },
    default: () => [] as BaseMessage[],
  }),
  llmCalls: z.number().register(registry, {
    reducer: {
      fn: (x, y) => (x ?? 0) + (y ?? 0),
    },
    default: () => 0,
  }),
});

type AgentStateType = z.infer<typeof AgentState>;

export class AgentConfig {
  private modelName: string;
  private model: ChatVertexAI;
  private agent: ReturnType<typeof this.buildAgent>;
  private metricsService: MetricsService;
  private knowledgeBaseService: knowledgeBaseService;

  async shouldContinue(state: AgentStateType) {
    return 'true';
  }

  private collectMetrics(state: AgentStateType) {
    const data = this.metricsService.getMetrics("k8s_workload");
    return {
      messages: [new SystemMessage(`
          Metrics collected from Prometheus as follows:
          ${data ?? 'No data available'}
        `)],
    }
  }

  private async retriveKnowledge(state: AgentStateType) {
    const relevantWords: string = "example keywords"; // This would be extracted from the state in a real implementation
    const context = await this.knowledgeBaseService.getKnowledge(relevantWords);
    return {
      messages: [new SystemMessage(`
          Retrieved knowledge from knowledge base:
          ${context}
        `)]
    };
  }

  private async analyzeRootCause(state: AgentStateType) {
    
    // Analyze the messages to determine root cause by LLM
    const message = await this.model.invoke([
      new SystemMessage(
        "You are an expert incident analyst. Based on the following conversation and metrics, identify the root cause of the incident."
      ),
      ...state.messages,
    ]);

    return { messages: [message], llmCalls: 1  };
  }

  private async applyRemediation(state: AgentStateType) {
    // Apply remediation steps based on analysis
    // Interact with k8s operator

  }

  private async needAssistance(state: AgentStateType) {
    // Determine if human assistance is needed

  }

  private async verifyResolution(state: AgentStateType) {
    // Verify if the incident has been resolved
    // The agent should monitor metrics and confirm resolution
  }

  private async updateKnowledgeBase(state: AgentStateType) {
    // embeddings and vector db update
    return {
      messages: [new SystemMessage("Summary of incident for knowledge base update.")],
    }
  }

  private async generateIncidentReport(state: AgentStateType) {
    
  }
  
  /**
   * Build an agent with a graph
   * @returns StateGraph instance
   */
  private buildAgent() {
    return new StateGraph(AgentState)
      .addNode("collectMetrics", this.collectMetrics)
      .addNode("retriveKnowledge", this.retriveKnowledge)
      .addNode("applyRemediation", this.applyRemediation)
      .addNode("analyzeRootCause", this.analyzeRootCause)
      .addNode("verifyResolution", this.verifyResolution)
      .addNode("updateKnowledgeBase", this.updateKnowledgeBase)
      .addNode("generateIncidentReport", this.generateIncidentReport)
      .addEdge(START, "collectMetrics")
      .addEdge("collectMetrics", "retriveKnowledge")
      .addEdge("retriveKnowledge", "analyzeRootCause")
      .addEdge("analyzeRootCause", "applyRemediation")
      .addEdge("applyRemediation", "verifyResolution")
      .addConditionalEdges("verifyResolution", this.shouldContinue, {
        true: "analyzeRootCause",
        false: "generateIncidentReport"
      })
      .addEdge("generateIncidentReport", "updateKnowledgeBase")
      .addEdge("updateKnowledgeBase", END)
      .compile();
  }

  async streamAgent(input: string, onChunk: (chunk: any) => void) {
    const state = {
      messages: [new HumanMessage({ content: input })],
      llmCalls: 0,
    };

    const stream = await this.agent.stream(state, { streamMode: "messages" });

    for await (const [messageChunk] of stream) {
      onChunk(messageChunk);
    }
  }

  constructor(metricsService: MetricsService, knowledgeBaseService: knowledgeBaseService) {
    this.modelName = config.model || "gemini-1.5-flash";
    this.model = new ChatVertexAI({
      model: this.modelName,
      temperature: 0.7,
      maxOutputTokens: 2048,
    });
    this.metricsService = metricsService;
    this.knowledgeBaseService = knowledgeBaseService;
    this.agent = this.buildAgent();
  }
}

// async function toolNode(state: MessagesStateType) {
//   const lastMessage = state.messages[state.messages.length - 1];

//   if (lastMessage == null || lastMessage._getType() !== "ai") {
//     return { messages: [] };
//   }

//   const aiMessage = lastMessage as AIMessage;
//   const result: ToolMessage[] = [];
//   for (const toolCall of aiMessage.tool_calls ?? []) {
//     const tool = toolsByName[toolCall.name];
//     const observation = await tool.invoke(toolCall);
//     result.push(observation);
//   }

//   return { messages: result };
// }

// const multiplyTool = tool(
//   async ({ a, b }: { a: number; b: number }) => {
//     return a * b;
//   },
//   {
//     name: "multiply",
//     description: "Multiply two numbers",
//     schema: z.object({
//       a: z.number().describe("First number"),
//       b: z.number().describe("Second number"),
//     }),
//   }
// );
// const modelWithTools = model.bindTools(tools);