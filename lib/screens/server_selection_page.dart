import 'package:flutter/material.dart';
import 'package:flutter_v2ray/url/url.dart';

class ServerSelectionPage extends StatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  State<ServerSelectionPage> createState() => _ServerSelectionPageState();
}

class _ServerSelectionPageState extends State<ServerSelectionPage> {
  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Server')),
      body: ListView.builder(
        itemCount: appState.servers.length,
        itemBuilder: (context, index) {
          final server = appState.servers[index];
          return Card(
            child: ListTile(
              title: Text(server.remark),
              trailing: appState.selectedServer == server
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                appState.selectedServer = server;
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}

// Class for managing app state
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  static AppState get instance => _instance;

  String? subscriptionLink;
  List<V2RayURL> servers = [];
  V2RayURL? selectedServer;
}
