import {
  AstraDBVectorStore,
  AstraLibArgs,
} from "@langchain/community/vectorstores/astradb";
import { Embeddings } from "@langchain/core/embeddings";
import { VectorStore } from "@langchain/core/vectorstores";
import { OpenAIEmbeddings } from "@langchain/openai";

export class knowledgeBaseService {
  private embeddings: Embeddings;
  private vectorStore: VectorStore;
  
  constructor() {
    this.embeddings = new OpenAIEmbeddings({
      batchSize: 512,
      model: "text-embedding-3-small",
    });

    const astraConfig: AstraLibArgs = {
      endpoint: process.env.ASTRA_DB_API_ENDPOINT || "",
      token: process.env.ASTRA_DB_APPLICATION_TOKEN || "",
      collection: process.env.ASTRA_DB_COLLECTION || "",
      collectionOptions: {
        vector: {
          dimension: 1536,
          metric: "cosine",
        }
      }
    };

    this.vectorStore = new AstraDBVectorStore(this.embeddings, astraConfig);
    console.log("KnowledgeBaseService initialized");
  }

  async addKnowledge(texts: string[], metadatas?: object[]) {
    await this.vectorStore.addDocuments(texts.map((text, idx) => ({
      pageContent: text,
      metadata: metadatas ? metadatas[idx] : {},
    })));

    console.log(`Added ${texts.length} documents to the knowledge base`);
  }

  async getKnowledge(topic: string): Promise<string> {
    const results = await this.vectorStore.similaritySearch(topic, 5);
    console.log(`Retrieved ${results.length} documents for topic: ${topic}`);
    return results.map(doc => doc.pageContent).join("\n---\n");
  }
}