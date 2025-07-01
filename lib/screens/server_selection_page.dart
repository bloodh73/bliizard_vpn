import 'package:flutter/material.dart';
import 'package:blizzard_vpn/models/app_state.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart'; // این ایمپورت همچنان برای V2RayURL لازم است
import 'package:blizzard_vpn/components/custom_snackbar.dart';
import 'dart:io'; // برای Socket
import 'dart:async'; // برای TimeoutException

class ServerSelectionPage extends StatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  State<ServerSelectionPage> createState() => _ServerSelectionPageState();
}

class _ServerSelectionPageState extends State<ServerSelectionPage> {
  List<V2RayURL> _servers = [];
  bool _isLoadingServers = false;
  bool _isPinging = false;
  Map<String, int?> _serverPings =
      {}; // Map برای ذخیره پینگ هر سرور (remark -> ping value)

  @override
  void initState() {
    super.initState();
    _loadServers(); // بارگذاری اولیه سرورها و سپس پینگ گرفتن
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoadingServers = true;
      _serverPings.clear(); // هنگام بارگذاری مجدد، پینگ‌ها را پاک کن
    });
    try {
      await AppState.instance
          .fetchAndParseServers(); // فراخوانی متد دریافت سرور از AppState
      setState(() {
        _servers = AppState.instance.servers;
      });
      // After loading servers, you can automatically ping
      _pingAllServers();
    } catch (e) {
      _showErrorSnackbar('Failed to load servers: $e');
    } finally {
      setState(() {
        _isLoadingServers = false;
      });
    }
  }

  // --- Method for network ping (TCP connection test) ---
  Future<int?> _performNetworkPing(V2RayURL server) async {
    try {
      final startTime = DateTime.now();
      // Attempt to connect to the server's TCP socket
      await Socket.connect(
        server.address, // Use the server's address
        server.port, // Use the server's port
        timeout: const Duration(seconds: 5), // 5 seconds timeout
      );
      final endTime = DateTime.now();
      final ping = endTime.difference(startTime).inMilliseconds;
      return ping;
    } on TimeoutException catch (_) {
      debugPrint('Ping timeout for ${server.remark}');
      return null; // Indicates unresponsiveness or timeout
    } on SocketException catch (e) {
      debugPrint('Socket error for ${server.remark.toString()}: ${e.message}');
      return null; // Indicates inability to connect (e.g., host not found, port closed)
    } catch (e) {
      debugPrint('Unexpected error during ping for ${server.remark}: $e');
      return null;
    }
  }

  Future<void> _pingAllServers() async {
    setState(() {
      _isPinging = true;
      _serverPings.clear(); // Clear previous pings
    });

    final tempPings = <String, int?>{};
    for (final server in _servers) {
      final ping = await _performNetworkPing(
        server,
      ); // Use the network ping method
      tempPings[server.remark] = ping;

      // Gradually update UI to see pings as they are received
      if (mounted) {
        setState(() {
          _serverPings = Map.from(tempPings);
        });
      }
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Small delay between pings
    }

    if (mounted) {
      setState(() {
        _serverPings = Map.from(tempPings); // Final update
        _isPinging = false;
      });
    }
    _showInfoSnackbar('Ping test completed.');
  }

  void _sortServersByPing() {
    setState(() {
      _servers.sort((a, b) {
        final pingA = _serverPings[a.remark];
        final pingB = _serverPings[b.remark];

        if (pingA == null && pingB == null) return 0;
        if (pingA == null) return 1; // Null pings (unreachable) go to the end
        if (pingB == null) return -1;
        return pingA.compareTo(pingB);
      });
    });
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      CustomSnackbar.show(
        context: context,
        message: message,
        backgroundColor: Colors.redAccent,
        icon: Icons.error,
      );
    }
  }

  void _showInfoSnackbar(String message) {
    if (mounted) {
      CustomSnackbar.show(
        context: context,
        message: message,
        backgroundColor: Colors.blueAccent,
        icon: Icons.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Server'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoadingServers || _isPinging ? null : _loadServers,
            tooltip: 'Refresh Servers and Ping',
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _isLoadingServers || _isPinging
                ? null
                : _sortServersByPing,
            tooltip: 'Sort by Ping',
          ),
        ],
      ),
      body: _isLoadingServers
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No servers available. Please add subscription links.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loadServers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload Servers'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _servers.length,
              itemBuilder: (context, index) {
                final server = _servers[index];
                final ping = _serverPings[server.remark];
                final isSelected = AppState.instance.selectedServer == server;

                Color pingColor = Colors.grey;
                String pingStatusText = 'Ping: N/A';

                if (_isPinging && ping == null) {
                  pingStatusText = 'Pinging...'; // Still trying to ping
                  pingColor = Colors.yellow;
                } else if (ping != null) {
                  pingStatusText = 'Ping: ${ping}ms';
                  if (ping < 100) {
                    pingColor = Colors.green;
                  } else if (ping < 300) {
                    pingColor = Colors.orange;
                  } else {
                    pingColor = Colors.red;
                  }
                } else {
                  // ping is null and _isPinging is false, means ping attempt failed
                  pingStatusText =
                      'Ping: Unreachable'; // Server is disconnected/unreachable
                  pingColor = Colors.red;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.dns,
                      color: isSelected
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(server.remark),
                    subtitle: Text(
                      pingStatusText,
                      style: TextStyle(color: pingColor),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        AppState.instance.selectedServer = server;
                      });
                      Navigator.pop(
                        context,
                        true,
                      ); // Return to main page and notify server selection
                    },
                  ),
                );
              },
            ),
    );
  }
}
