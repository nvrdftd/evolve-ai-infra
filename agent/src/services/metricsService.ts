import { setInterval } from 'timers';
import axios from 'axios';
import { config } from '../utils'

interface QueueMessage {
    type: 'update' | 'delete';
    name: string;
    data?: any;
}

export class MetricsService {
    private metrics: Record<string, number[]>;
    private queue: QueueMessage[];
    private ttl: number; // TTL for metrics in seconds
    private httpClient = axios.create({
        baseURL: config.metricsEndpoint || '',
        timeout: 1000
    });

    constructor(ttl?: number) {
        this.metrics = {};
        this.queue = [];
        this.ttl = ttl || 300; // Default TTL is 5 minutes
        this.start();
    }

    private start() {
        console.log("MetricsService started");
        setInterval(() => {
            this.recordMetric("workqueue_work_duration_seconds", Math.random() * 100);
        }, 10000); // Log metrics every 10 seconds
        setInterval(() => {
            this.processQueue();
        }, 5000); // Process queue every 5 seconds
    }

    private enqueue(message: QueueMessage): void {
        this.queue.push(message);
    }

    private processQueue(): void {
        while (this.queue.length > 0) {
            const msg = this.dequeue();
            if (msg.type === 'update' && msg.data !== undefined) {
                console.log(`Metric Updated: ${msg.name} = ${msg.data}`);
            } else if (msg.type === 'delete') {
                console.log(`Metric Deleted: ${msg.name}`);
            }
        }
    }

    private dequeue(): QueueMessage {
        const msg = this.queue.shift();
        return msg ?? { type: 'delete', name: '', data: undefined };
    }

    private async recordMetric(name: string, value: number): Promise<void> {
        if (!this.metrics[name]) {
            this.metrics[name] = [];
        }

        this.queryProm('rate(workqueue_work_duration_seconds_sum{name="deployment"}[5m])')

        this.enqueue({ type: 'update', name, data: value });

        this.ttl && setTimeout(() => {
            this.enqueue({ type: 'delete', name });
        }, this.ttl * 1000);

        this.metrics[name].push(value);
    }

    getMetrics(name: string): number[] | undefined {
        return this.metrics[name];
    }

    async queryProm(query: string): Promise<any> {
        const res = await this.httpClient.get('/api/v1/query', {
            params: { query: query.trim() }
        })
        
        if (res.status !== 200 || res.data.status !== 'success') {
            throw new Error(`Failed to fetch metrics: ${res.statusText}`);
        }

        return res.data
    }
}