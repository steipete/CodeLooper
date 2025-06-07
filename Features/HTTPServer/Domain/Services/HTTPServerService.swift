import Foundation
import Network
import Defaults
import Diagnostics

extension DisplayStatus {
    var description: String {
        return self.rawValue
    }
}

/// HTTP server service for remote monitoring and control of instances
@MainActor
final class HTTPServerService: ObservableObject {
    private let logger = Logger(category: .networking)
    private var listener: NWListener?
    @Published private(set) var isRunning = false
    
    static let shared = HTTPServerService()
    
    private init() {
        logger.info("HTTPServerService initialized")
    }
    
    /// Start the HTTP server if enabled in settings
    func startIfEnabled() async {
        guard Defaults[.httpServerEnabled] else { return }
        await self.startServer()
    }
    
    /// Start the HTTP server
    func startServer() async {
        guard !isRunning else { return }
        
        do {
            let port = Defaults[.httpServerPort]
            let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
            
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: nwPort)
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.logger.info("HTTP server started on port \(port)")
                        self?.isRunning = true
                    case .failed(let error):
                        self?.logger.error("HTTP server failed: \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.logger.info("HTTP server cancelled")
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handleConnection(connection)
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            logger.error("Failed to start HTTP server: \(error)")
        }
    }
    
    /// Stop the HTTP server
    func stopServer() async {
        guard isRunning else { return }
        
        listener?.cancel()
        listener = nil
        isRunning = false
        logger.info("HTTP server stopped")
    }
    
    /// Restart the server (useful when settings change)
    func restartServer() async {
        await self.stopServer()
        await self.startServer()
    }
    
    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))
        
        // Read HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data else { return }
            
            Task {
                await self.processRequest(data: data, connection: connection)
            }
        }
    }
    
    private func processRequest(data: Data, connection: NWConnection) async {
        guard let requestString = String(data: data, encoding: .utf8) else {
            connection.cancel()
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            connection.cancel()
            return
        }
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            connection.cancel()
            return
        }
        
        let method = components[0]
        let path = components[1]
        
        var responseData: Data
        
        // Parse path and query parameters
        let pathComponents = path.components(separatedBy: "?")
        let cleanPath = pathComponents.first ?? path
        
        switch (method, cleanPath) {
        case ("GET", "/"):
            let response = await createHTMLResponse()
            responseData = response.data(using: .utf8) ?? Data()
        case ("GET", "/api/instances"):
            let response = await createJSONResponse()
            responseData = response.data(using: .utf8) ?? Data()
        case ("GET", _) where cleanPath.hasPrefix("/api/claude/"):
            let id = String(cleanPath.dropFirst("/api/claude/".count))
            let response = await createClaudeDetailResponse(id: id)
            responseData = response.data(using: .utf8) ?? Data()
        case ("GET", _) where cleanPath.hasPrefix("/api/cursor/"):
            let id = String(cleanPath.dropFirst("/api/cursor/".count))
            let response = await createCursorDetailResponse(id: id)
            responseData = response.data(using: .utf8) ?? Data()
        case ("GET", "/api/status"):
            let response = await createStatusResponse()
            responseData = response.data(using: .utf8) ?? Data()
        case ("GET", "/favicon.ico"):
            responseData = createFaviconResponse()
        default:
            let response = createNotFoundResponse()
            responseData = response.data(using: .utf8) ?? Data()
        }
        
        // Send response
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func createHTMLResponse() async -> String {
        let html = await renderMainPage()
        return """
        HTTP/1.1 200 OK\\r
        Content-Type: text/html\\r
        Content-Length: \(html.utf8.count)\\r
        \\r
        \(html)
        """
    }
    
    private func createJSONResponse() async -> String {
        let instances = await getInstances()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(instances),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return createErrorResponse()
        }
        
        return """
        HTTP/1.1 200 OK\\r
        Content-Type: application/json\\r
        Access-Control-Allow-Origin: *\\r
        Content-Length: \(jsonString.utf8.count)\\r
        \\r
        \(jsonString)
        """
    }
    
    private func createNotFoundResponse() -> String {
        let body = "404 Not Found"
        return """
        HTTP/1.1 404 Not Found\\r
        Content-Type: text/plain\\r
        Content-Length: \(body.utf8.count)\\r
        \\r
        \(body)
        """
    }
    
    private func createErrorResponse() -> String {
        let body = "500 Internal Server Error"
        return """
        HTTP/1.1 500 Internal Server Error\\r
        Content-Type: text/plain\\r
        Content-Length: \(body.utf8.count)\\r
        \\r
        \(body)
        """
    }
    
    private func renderMainPage() async -> String {
        let port = Defaults[.httpServerPort]
        let refreshRate = Defaults[.httpServerScreenshotRefreshRate]
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>CodeLooper Remote Control</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                    margin: 0; 
                    padding: 20px; 
                    background: #f5f5f7; 
                    color: #1d1d1f;
                }
                .container { max-width: 1200px; margin: 0 auto; }
                .header { 
                    background: white; 
                    padding: 30px; 
                    border-radius: 12px; 
                    margin-bottom: 20px; 
                    text-align: center;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
                }
                .header h1 { margin: 0 0 10px 0; color: #1d1d1f; font-size: 2.5em; font-weight: 600; }
                .header p { color: #86868b; margin: 0 0 20px 0; font-size: 1.1em; }
                .controls { 
                    display: flex; 
                    gap: 15px; 
                    justify-content: center; 
                    align-items: center; 
                    flex-wrap: wrap; 
                }
                .refresh-button { 
                    background: #007aff; 
                    color: white; 
                    padding: 12px 24px; 
                    border: none; 
                    border-radius: 8px; 
                    cursor: pointer; 
                    font-size: 1em; 
                    transition: background 0.2s; 
                }
                .refresh-button:hover { background: #0056cc; }
                .info-text { color: #86868b; font-size: 0.9em; }
                
                .instances { 
                    display: grid; 
                    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); 
                    gap: 20px; 
                }
                .instance-card { 
                    background: white; 
                    padding: 25px; 
                    border-radius: 12px; 
                    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
                    border: 1px solid #e5e5e7;
                }
                .instance-card.claude { border-left: 4px solid #ff9500; }
                .instance-card.cursor { border-left: 4px solid #007aff; }
                .instance-header { 
                    display: flex; 
                    justify-content: space-between; 
                    align-items: center; 
                    margin-bottom: 20px; 
                }
                .instance-title { font-weight: 600; margin: 0; font-size: 1.2em; }
                .instance-status { 
                    padding: 6px 12px; 
                    border-radius: 6px; 
                    font-size: 0.8em; 
                    font-weight: 500; 
                }
                .status-active { background: #d1f2eb; color: #00875a; }
                .status-inactive { background: #ffebe6; color: #de350b; }
                .instance-details { margin: 15px 0; font-size: 0.9em; color: #86868b; line-height: 1.6; }
                .detail-row { 
                    display: flex; 
                    justify-content: space-between; 
                    margin-bottom: 8px; 
                }
                .detail-label { font-weight: 500; color: #1d1d1f; }
                .no-instances { 
                    text-align: center; 
                    padding: 60px 20px; 
                    color: #86868b; 
                    font-size: 1.1em; 
                }
                .loading { text-align: center; padding: 40px; color: #86868b; }
                .error { 
                    background: #ffebe6; 
                    color: #de350b; 
                    padding: 20px; 
                    border-radius: 12px; 
                    margin: 20px 0; 
                    text-align: center; 
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>CodeLooper Remote Control</h1>
                    <p>Monitor your Claude and Cursor instances remotely</p>
                    <div class="controls">
                        <button class="refresh-button" onclick="loadInstances()">Refresh Instances</button>
                        <span class="info-text">Port \(port)</span>
                        <span class="info-text">•</span>
                        <span class="info-text">Refresh: \(refreshRate)ms</span>
                    </div>
                </div>
                <div id="instances" class="instances">
                    <div class="loading">Loading instances...</div>
                </div>
            </div>
            
            <script>
                async function loadInstances() {
                    try {
                        const response = await fetch('/api/instances');
                        if (!response.ok) {
                            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                        }
                        const data = await response.json();
                        renderInstances(data);
                    } catch (error) {
                        console.error('Error loading instances:', error);
                        document.getElementById('instances').innerHTML = 
                            `<div class="error">Error loading instances: ${error.message}</div>`;
                    }
                }
                
                function renderInstances(data) {
                    const container = document.getElementById('instances');
                    let html = '';
                    
                    // Render Claude instances
                    if (data.claudeInstances && data.claudeInstances.length > 0) {
                        data.claudeInstances.forEach(instance => {
                            html += renderClaudeInstance(instance);
                        });
                    }
                    
                    // Render Cursor instances
                    if (data.cursorInstances && data.cursorInstances.length > 0) {
                        data.cursorInstances.forEach(instance => {
                            html += renderCursorInstance(instance);
                        });
                    }
                    
                    if (html === '') {
                        html = '<div class="no-instances">No instances found. Make sure Claude or Cursor are running and being monitored by CodeLooper.</div>';
                    }
                    
                    container.innerHTML = html;
                }
                
                function renderClaudeInstance(instance) {
                    const statusClass = instance.isActive ? 'status-active' : 'status-inactive';
                    const statusText = instance.isActive ? 'Active' : 'Inactive';
                    const lastSeen = new Date(instance.lastSeen).toLocaleString();
                    
                    return `
                        <div class="instance-card claude">
                            <div class="instance-header">
                                <h3 class="instance-title">Claude: ${escapeHtml(instance.windowTitle)}</h3>
                                <span class="instance-status ${statusClass}">${statusText}</span>
                            </div>
                            <div class="instance-details">
                                <div class="detail-row">
                                    <span class="detail-label">Instance ID:</span>
                                    <span>${escapeHtml(instance.id.substring(0, 8))}...</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Process ID:</span>
                                    <span>${instance.processId}</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Last Seen:</span>
                                    <span>${lastSeen}</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Activity:</span>
                                    <span>${escapeHtml(instance.textContent || 'None')}</span>
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                function renderCursorInstance(instance) {
                    const statusClass = instance.isActive ? 'status-active' : 'status-inactive';
                    const statusText = instance.isActive ? 'Active' : 'Inactive';
                    const lastSeen = new Date(instance.lastSeen).toLocaleString();
                    
                    return `
                        <div class="instance-card cursor">
                            <div class="instance-header">
                                <h3 class="instance-title">Cursor: ${escapeHtml(instance.windowTitle)}</h3>
                                <span class="instance-status ${statusClass}">${statusText}</span>
                            </div>
                            <div class="instance-details">
                                <div class="detail-row">
                                    <span class="detail-label">Instance ID:</span>
                                    <span>${escapeHtml(instance.id.substring(0, 8))}...</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Process ID:</span>
                                    <span>${instance.processId}</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Status:</span>
                                    <span>${escapeHtml(instance.status)}</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Last Seen:</span>
                                    <span>${lastSeen}</span>
                                </div>
                                <div class="detail-row">
                                    <span class="detail-label">Document:</span>
                                    <span>${escapeHtml(instance.textContent || 'None')}</span>
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                function escapeHtml(text) {
                    const map = {
                        '&': '&amp;',
                        '<': '&lt;',
                        '>': '&gt;',
                        '"': '&quot;',
                        "'": '&#039;'
                    };
                    return text.replace(/[&<>"']/g, function(m) { return map[m]; });
                }
                
                // Initialize
                loadInstances();
                
                // Auto-refresh instances
                setInterval(loadInstances, \(refreshRate));
            </script>
        </body>
        </html>
        """
    }
    
    private func getInstances() async -> InstancesResponse {
        let claudeInstances = await getClaudeInstances()
        let cursorInstances = await getCursorInstances()
        
        return InstancesResponse(
            claudeInstances: claudeInstances,
            cursorInstances: cursorInstances,
            timestamp: Date()
        )
    }
    
    private func getClaudeInstances() async -> [HTTPClaudeInstanceInfo] {
        let claudeService = ClaudeMonitorService.shared
        
        return claudeService.instances.map { instance in
            HTTPClaudeInstanceInfo(
                id: instance.id.uuidString,
                windowTitle: instance.folderName,
                processId: instance.pid,
                isActive: true,
                lastSeen: instance.lastUpdated,
                textContent: instance.currentActivity.text
            )
        }
    }
    
    private func getCursorInstances() async -> [HTTPCursorInstanceInfo] {
        let cursorMonitor = CursorMonitor.shared
        let cursorApps = cursorMonitor.monitoredApps
        
        var instances: [HTTPCursorInstanceInfo] = []
        
        for app in cursorApps {
            for window in app.windows {
                instances.append(HTTPCursorInstanceInfo(
                    id: window.id,
                    windowTitle: window.windowTitle ?? "Unknown",
                    processId: app.pid,
                    isActive: app.isActivelyMonitored,
                    lastSeen: Date(),
                    textContent: window.documentPath,
                    status: app.status.description
                ))
            }
        }
        
        return instances
    }
    
    // MARK: - Additional Response Methods
    
    private func createClaudeDetailResponse(id: String) async -> String {
        let claudeService = ClaudeMonitorService.shared
        guard let instance = claudeService.instances.first(where: { $0.id.uuidString == id }) else {
            return createNotFoundResponse()
        }
        
        let detail = HTTPClaudeInstanceInfo(
            id: instance.id.uuidString,
            windowTitle: instance.folderName,
            processId: instance.pid,
            isActive: true,
            lastSeen: instance.lastUpdated,
            textContent: instance.currentActivity.text
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(detail),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return createErrorResponse()
        }
        
        return """
        HTTP/1.1 200 OK\\r
        Content-Type: application/json\\r
        Access-Control-Allow-Origin: *\\r
        Content-Length: \(jsonString.utf8.count)\\r
        \\r
        \(jsonString)
        """
    }
    
    private func createCursorDetailResponse(id: String) async -> String {
        let cursorMonitor = CursorMonitor.shared
        
        for app in cursorMonitor.monitoredApps {
            if let window = app.windows.first(where: { $0.id == id }) {
                let detail = HTTPCursorInstanceInfo(
                    id: window.id,
                    windowTitle: window.windowTitle ?? "Unknown",
                    processId: app.pid,
                    isActive: app.isActivelyMonitored,
                    lastSeen: Date(),
                    textContent: window.documentPath,
                    status: app.status.description
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                guard let jsonData = try? encoder.encode(detail),
                      let jsonString = String(data: jsonData, encoding: .utf8) else {
                    return createErrorResponse()
                }
                
                return """
                HTTP/1.1 200 OK\\r
                Content-Type: application/json\\r
                Access-Control-Allow-Origin: *\\r
                Content-Length: \(jsonString.utf8.count)\\r
                \\r
                \(jsonString)
                """
            }
        }
        
        return createNotFoundResponse()
    }
    
    private func createStatusResponse() async -> String {
        let status = [
            "serverVersion": "1.0",
            "serverUptime": "\(ProcessInfo.processInfo.systemUptime)",
            "claudeInstancesCount": "\(ClaudeMonitorService.shared.instances.count)",
            "cursorInstancesCount": "\(CursorMonitor.shared.monitoredApps.reduce(0) { $0 + $1.windows.count })",
            "httpServerPort": "\(Defaults[.httpServerPort])",
            "refreshRate": "\(Defaults[.httpServerScreenshotRefreshRate])"
        ]
        
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(status),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return createErrorResponse()
        }
        
        return """
        HTTP/1.1 200 OK\\r
        Content-Type: application/json\\r
        Access-Control-Allow-Origin: *\\r
        Content-Length: \(jsonString.utf8.count)\\r
        \\r
        \(jsonString)
        """
    }
    
    private func createFaviconResponse() -> Data {
        // CodeLooper icon - chain link emoji as base64
        let faviconBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        
        guard let iconData = Data(base64Encoded: faviconBase64) else {
            return createNotFoundResponse().data(using: .utf8) ?? Data()
        }
        
        let headers = """
        HTTP/1.1 200 OK\\r
        Content-Type: image/png\\r
        Content-Length: \(iconData.count)\\r
        Cache-Control: public, max-age=86400\\r
        \\r
        """
        
        var response = Data(headers.utf8)
        response.append(iconData)
        
        return response
    }
}