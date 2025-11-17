import { tool } from "@langchain/core/tools";
import { StateGraph, START, END, Annotation } from "@langchain/langgraph";
import { BaseMessage, HumanMessage, SystemMessage } from "@langchain/core/messages";
import { ChatVertexAI } from "@langchain/google-vertexai";
import { z } from "zod";
import { config, getPromMetrics } from "./util";

// Define tools for the agent
const addTool = tool(
  async ({ a, b }: { a: number; b: number }) => {
    return a + b;
  },
  {
    name: "add",
    description: "Add two numbers",
    schema: z.object({
      a: z.number().describe("First number"),
      b: z.number().describe("Second number"),
    }),
  }
);

const multiplyTool = tool(
  async ({ a, b }: { a: number; b: number }) => {
    return a * b;
  },
  {
    name: "multiply",
    description: "Multiply two numbers",
    schema: z.object({
      a: z.number().describe("First number"),
      b: z.number().describe("Second number"),
    }),
  }
);

const tools = [addTool, multiplyTool];
const toolsByName: Record<string, typeof addTool | typeof multiplyTool> = {
  add: addTool,
  multiply: multiplyTool,
};

const model = new ChatVertexAI({
  model: "gemini-1.5-flash",
  temperature: 0.7,
  maxOutputTokens: 2048,
});

const modelWithTools = model.bindTools(tools);

const MessagesState = Annotation.Root({
  messages: Annotation<BaseMessage[]>({
    reducer: (x, y) => x.concat(y),
  }),
  llmCalls: Annotation<number>({
    reducer: (x, y) => (x ?? 0) + (y ?? 0),
  }),
});

type MessagesStateType = typeof MessagesState.State;

async function llmCall(state: MessagesStateType) {
  return {
    messages: await modelWithTools.invoke([
      new SystemMessage(
        "You are a helpful assistant tasked with performing arithmetic on a set of inputs."
      ),
      ...state.messages,
    ]),
    llmCalls: (state.llmCalls ?? 0) + 1,
  };
}

import { AIMessage, ToolMessage } from "@langchain/core/messages";
async function toolNode(state: MessagesStateType) {
  const lastMessage = state.messages[state.messages.length - 1];

  if (lastMessage == null || lastMessage._getType() !== "ai") {
    return { messages: [] };
  }

  const aiMessage = lastMessage as AIMessage;
  const result: ToolMessage[] = [];
  for (const toolCall of aiMessage.tool_calls ?? []) {
    const tool = toolsByName[toolCall.name];
    const observation = await tool.invoke(toolCall);
    result.push(observation);
  }

  return { messages: result };
}

async function shouldContinue(state: MessagesStateType) {
  const lastMessage = state.messages[state.messages.length - 1];
  if (lastMessage == null || lastMessage._getType() !== "ai") return END;

  const aiMessage = lastMessage as AIMessage;
  // If the LLM makes a tool call, then perform an action
  if (aiMessage.tool_calls?.length) {
    return "toolNode";
  }

  return END;
}

async function collectMetrics(state: MessagesStateType) {
  const data = await getPromMetrics("up");
  return {
    messages: [{
      type: "system",
      content: `
        Metrics collected from Prometheus as follows:
        ${data}
      `,
    }],
  }
}

async function analyzeRootCause(state: MessagesStateType) {
  
  // Analyze the messages to determine root cause by LLM
  const message = await model.invoke([
    new SystemMessage(
      "You are an expert incident analyst. Based on the following conversation and metrics, identify the root cause of the incident."
    ),
    ...state.messages,
  ]);

  return { messages: [message] };
}

async function applyRemediation(state: MessagesStateType) {
  // Apply remediation steps based on analysis
}

async function needAssistance(state: MessagesStateType) {
  // Determine if human assistance is needed

}

async function verifyResolution(state: MessagesStateType) {
  // Verify if the incident has been resolved
  // The agent should monitor metrics and confirm resolution
}

async function updateKnowledgeBase(state: MessagesStateType) {
  return {
    messages: [{
      type: "agent",
      content: "Summary of incide",
    }],
  }
}

async function generateIncidentReport(state: MessagesStateType) {
  
}

// Build the graph
const agent = new StateGraph(MessagesState)
  .addNode("llmCall", llmCall)
  .addNode("toolNode", toolNode)
  .addEdge(START, "llmCall")
  .addConditionalEdges("llmCall", shouldContinue, ["toolNode", END])
  .addEdge("toolNode", "llmCall")
  .compile();

// Wrapper function to stream agent responses
async function streamAgent(
  message: string,
  onChunk: (chunk: any) => void
): Promise<void> {
  const stream = await agent.stream({
    messages: [new HumanMessage(message)],
  });

  for await (const chunk of stream) {
    onChunk(chunk);
  }
}

export { agent, streamAgent };