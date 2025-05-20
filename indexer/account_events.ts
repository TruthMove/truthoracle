/**
 * Live Account Event Streamer
 * 
 * Features:
 * - Streams live events related to a specific account using gRPC
 * - Emits events via WebSocket in real-time
 * - Robust gRPC connection handling with automatic reconnection
 * - WebSocket auto-reconnect and heartbeat
 * - Security features for production deployment
 * 
 * Requirements:
 * - An Aptos API key (get one from https://aptoslabs.com/developers)
 * - Set the API key in environment variable APTOS_API_KEY_TESTNET
 * - Bun runtime
 */

import { streamTransactions } from ".";
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "http";
import { parse } from "url";

// Configuration
const WS_PORT = Number(process.env.PORT || "8080");
const STARTING_VERSION = Number(process.env.STARTING_VERSION || "0");
const MODULE_ADDRESS = process.env.MODULE_ADDRESS || "0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace";
const MAX_RETRIES = 5;
const RETRY_DELAY = 5000; // 5 seconds
const WS_HEARTBEAT_INTERVAL = 30000; // 30 seconds
const WS_RECONNECT_INTERVAL = 5000; // 5 seconds
const MAX_CONNECTIONS = 1000; // Maximum number of concurrent connections
const RATE_LIMIT_WINDOW = 60000; // 1 minute
const MAX_MESSAGES_PER_WINDOW = 100; // Maximum messages per minute per client

// Create HTTP server for health checks
const server = createServer((req, res) => {
  const { pathname } = parse(req.url || '', true);
  
  if (pathname === '/health') {
    res.writeHead(200);
    res.end('OK');
    return;
  }
  
  res.writeHead(404);
  res.end();
});

// Initialize WebSocket server with security options
const wss = new WebSocketServer({ 
  server,
  perMessageDeflate: false,
  clientTracking: true,
  maxPayload: 1024 * 1024, // 1MB max payload
});

// Rate limiting
const rateLimits = new Map<string, { count: number; resetTime: number }>();

// Track active connections
const activeConnections = new Set<WebSocket>();

// Helper function to check if an event is related to our target account
function isAccountRelatedEvent(event: any): boolean {
  try {
    const eventData = JSON.parse(event.data);

    // MarketCreated event
    if (event.typeStr === `${MODULE_ADDRESS}::truthoracle::MarketCreated`) {
      return true;
    }

    // Buy shares event
    if (event.typeStr === `${MODULE_ADDRESS}::truthoracle::buy_shares`) {
      return true;
    }

    // Withdraw payout event
    if (event.typeStr === `${MODULE_ADDRESS}::truthoracle::withdraw_payout`) {
      return true;
    }
    
    return false;
  } catch (error) {
    console.error("Error checking event:", error);
    return false;
  }
}

// Setup heartbeat for a WebSocket connection
function setupHeartbeat(ws: WebSocket) {
  const heartbeat = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.ping();
    } else {
      clearInterval(heartbeat);
    }
  }, WS_HEARTBEAT_INTERVAL);

  ws.on('pong', () => {
    // Client is still alive
  });

  ws.on('close', () => {
    clearInterval(heartbeat);
    activeConnections.delete(ws);
  });

  return heartbeat;
}

// Check rate limit
function checkRateLimit(clientId: string): boolean {
  const now = Date.now();
  const limit = rateLimits.get(clientId);

  if (!limit || now > limit.resetTime) {
    rateLimits.set(clientId, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
    return true;
  }

  if (limit.count >= MAX_MESSAGES_PER_WINDOW) {
    return false;
  }

  limit.count++;
  return true;
}

// Handle WebSocket connections
wss.on("connection", (ws, req) => {
  // Check connection limit
  if (activeConnections.size >= MAX_CONNECTIONS) {
    ws.close(1013, "Server is at maximum capacity");
    return;
  }

  const clientId = req.socket.remoteAddress || 'unknown';
  console.log(`New WebSocket client connected from ${clientId}`);
  activeConnections.add(ws);
  
  // Setup heartbeat
  setupHeartbeat(ws);

  // Handle client messages
  ws.on("message", (data) => {
    if (!checkRateLimit(clientId)) {
      ws.send(JSON.stringify({ 
        type: "error", 
        message: "Rate limit exceeded" 
      }));
      return;
    }

    try {
      const message = JSON.parse(data.toString());
      if (message.type === "ping") {
        ws.send(JSON.stringify({ type: "pong" }));
      }
    } catch (error) {
      console.error("Error handling WebSocket message:", error);
    }
  });

  ws.on("close", () => {
    console.log(`Client ${clientId} disconnected`);
    activeConnections.delete(ws);
  });

  ws.on("error", (error) => {
    console.error(`WebSocket error for client ${clientId}:`, error);
  });

  // Send initial connection success message
  ws.send(JSON.stringify({ 
    type: "connection_status", 
    status: "connected",
    timestamp: Date.now()
  }));
});

// Broadcast to all connected clients
function broadcastToClients(data: any) {
  const message = JSON.stringify(data);
  activeConnections.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// Main processing loop with retry logic
async function streamLiveEvents(retryCount = 0, currentVersion = STARTING_VERSION) {
  try {
    console.log(`Starting stream from version ${currentVersion} (attempt ${retryCount + 1}/${MAX_RETRIES})`);
    
    for await (const event of streamTransactions({
      url: "grpc.testnet.aptoslabs.com:443",
      apiKey: process.env.APTOS_API_KEY_TESTNET!,
      // startingVersion: BigInt(currentVersion),
      startingVersion: 0n,
    })) {
      switch (event.type) {
        case "data": {
          if (event.chainId !== 2n) {
            throw new Error(
              `Transaction stream returned a chainId of ${event.chainId}, but expected testnet chainId=2`
            );
          }

          console.log('transactionLength', event.transactions.length, 'currentVersion', currentVersion);

          // Process each transaction
          for (const txn of event.transactions) {
            const version = txn.version!;
            const timestamp = Number(txn.timestamp.seconds)!;

            // Process each event in the transaction
            for (const evt of txn?.user?.events || []) {
              if (isAccountRelatedEvent(evt)) {
                console.log({ evt });

                // Broadcast to all connected WebSocket clients
                broadcastToClients({
                  type: "account_event",
                  data: {
                    version,
                    event_type: evt.typeStr,
                    event_data: JSON.parse(evt.data),
                    timestamp,
                  },
                });

                console.log(
                  `Found account-related event at version ${version}: ${evt.type}`
                );
              }
            }
          }
          break;
        }
        case "error": {
          console.error("Stream error:", event.error);
          // Check for connection drop
          if (event.error.code === 14 && event.error.details === "Connection dropped") {
            console.log(`Connection dropped, restarting from version ${currentVersion}`);
            return await streamLiveEvents(0, currentVersion); // Reset retry count but keep same version
          }
        }
        case "metadata": {
          break;
        }
        case "status": {
          if (event.status.code !== 0) { // 0 is OK
            console.error(`Stream status error: ${event.status.code} - ${event.status.details}`);
            // Check for wire type error
            if (event.status.code === 13 && event.status.details.includes("invalid wire type")) {
              console.log(`Encountered wire type error, incrementing version from ${currentVersion} to ${currentVersion + 1}`);
              return await streamLiveEvents(0, currentVersion + 1); // Reset retry count and increment version
            }
            // Check for connection drop
            if (event.status.code === 14 && event.status.details === "Connection dropped") {
              console.log(`Connection dropped, restarting from version ${currentVersion}`);
              return await streamLiveEvents(0, currentVersion); // Reset retry count but keep same version
            }
          }
          break;
        }
      }
    }
  } catch (error) {
    console.error("Error in main processing loop:", error);
    
    if (retryCount < MAX_RETRIES) {
      console.log(`Retrying in ${RETRY_DELAY/1000} seconds... (${retryCount + 1}/${MAX_RETRIES})`);
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY));
      return await streamLiveEvents(retryCount + 1, currentVersion);
    } else {
      console.error("Max retries reached. Please check your connection and API key.");
      process.exit(1);
    }
  }
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('Shutting down gracefully...');
  // Close all active connections
  activeConnections.forEach((ws) => {
    ws.close(1000, 'Server shutting down');
  });
  wss.close(() => {
    console.log('WebSocket server closed');
    process.exit(0);
  });
});

// Start the server
server.listen(WS_PORT, () => {
  console.log(`WebSocket server started on port ${WS_PORT}`);
  console.log(`Health check available at http://localhost:${WS_PORT}/health`);
  console.log(`Starting live event streamer for module: ${MODULE_ADDRESS}`);
  streamLiveEvents();
}); 