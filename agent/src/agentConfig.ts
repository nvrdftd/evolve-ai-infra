import { StateGraph, START, END} from "@langchain/langgraph";
import { registry } from "@langchain/langgraph/zod";
import { AIMessage, BaseMessage, HumanMessage, SystemMessage } from "@langchain/core/messages";
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


const KnowledgeTopics = z.array(
  z.string().describe("A topic relevant to infrastructure incidents")
)

const RemedyPlan = z.object({
  type: z.enum(['Scaling', 'Restart', 'ConfigUpdate', 'ResourceLimit']),
  targetKind: z.string(),
  targetName: z.string(),
  targetNamespace: z.string(),
  parameters: z.record(z.string(), z.string()).optional(),
  reasoning: z.string(),
});


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
      messages: [new SystemMessage(`Metrics collected from Prometheus as follows: ${data ?? 'No data available'}`)]
    }
  }

  private async analyzeMetrics(state: AgentStateType) {
    const modelWithKnowledgeTopics = this.model.withStructuredOutput(KnowledgeTopics);
    const topics = await modelWithKnowledgeTopics.invoke([
      new SystemMessage(
        "Analyze the following metrics and extract 3 topics that would be relevant for searching a knowledge base about Kubernetes incidents. \
        Return only comma-separated topics."
      ),
      ...state.messages,
    ]);
    return {
      messages: [new AIMessage(`Extracted knowledge topics: ${topics.join(", ")}`)],
      llmCalls: 1
    };
  }

  private async retriveKnowledge(state: AgentStateType) {
    const topicsMessage = state.messages[state.messages.length -1];
    const context = await this.knowledgeBaseService.getKnowledge(topicsMessage.text);
    return {
      messages: [new SystemMessage(`
          Retrieved context from knowledge base:
          ${context}
        `)]
    };
  }

  private async findRootCause(state: AgentStateType) {
    // Analyze the messages to determine root cause by LLM
    const message = await this.model.invoke([
      new SystemMessage(
        "You are an expert incident analyst. Based on the following context and metrics, identify the root cause of any possible incident. \
        It is not always to have an incident regarding the application service behavior \
        Provide a concise explanation of the root cause if anything."
      ),
      ...state.messages,
    ]);

    return { messages: [new AIMessage(message)], llmCalls: 1  };
  }

  private async applyRemedy(state: AgentStateType) {
    const remedyPlan = await this.model.withStructuredOutput(RemedyPlan).invoke([
      new SystemMessage(
        "Based on the root cause analysis, determine the appropriate remediation action. \
        Consider scaling (increase/decrease replicas), restart (rolling restart), \
        config updates, or resource limit adjustments."
      ),
      ...state.messages,
    ]);

    // Interact with k8s using k8sService
    return {
      messages: [new AIMessage(
        `Applied remediation: ${remedyPlan.type} for ${remedyPlan.targetKind}/${remedyPlan.targetName}. \
        Reasoning: ${remedyPlan.reasoning}`
      )],
      llmCalls: 1,
    };
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
      .addNode("analyzeMetrics", this.analyzeMetrics)
      .addNode("retriveKnowledge", this.retriveKnowledge)
      .addNode("applyRemedy", this.applyRemedy)
      .addNode("findRootCause", this.findRootCause)
      .addNode("verifyResolution", this.verifyResolution)
      .addNode("updateKnowledgeBase", this.updateKnowledgeBase)
      .addNode("generateIncidentReport", this.generateIncidentReport)
      .addEdge(START, "collectMetrics")
      .addEdge("collectMetrics", "analyzeMetrics")
      .addEdge("analyzeMetrics", "retriveKnowledge")
      .addEdge("retriveKnowledge", "findRootCause")
      .addEdge("findRootCause", "applyRemedy")
      .addEdge("applyRemedy", "verifyResolution")
      .addConditionalEdges("verifyResolution", this.shouldContinue, {
        true: "findRootCause",
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