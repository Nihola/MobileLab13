import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin localNotifications =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await _setupLocalNotifications();
  await _setupFCM();

  runApp(const MyApp());
}

// ---------------------------
// LOCAL NOTIFICATIONS SETUP
// ---------------------------
Future<void> _setupLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: android);

  await localNotifications.initialize(initSettings);
}

// ---------------------------
// FIREBASE CLOUD MESSAGING SETUP
// ---------------------------
Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  // Request permission (required)
  await messaging.requestPermission();

  // Get FCM token
  final token = await messaging.getToken();
  print("FCM TOKEN: $token");

  // Foreground message handling
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    localNotifications.show(
      0,
      message.notification?.title ?? "New Notification",
      message.notification?.body ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'main_channel',
          'Main Channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  });
}

// ---------------------------
// ROOT APP WIDGET
// ---------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Messages App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

// ---------------------------
// HOME PAGE
// ---------------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Messages CRUD + FCM")),
      body: Column(
        children: const [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: MessageForm(),
          ),
          Expanded(child: MessageList()),
        ],
      ),
    );
  }
}

// ---------------------------
// MESSAGE INPUT FORM
// ---------------------------
class MessageForm extends StatefulWidget {
  const MessageForm({super.key});

  @override
  State<MessageForm> createState() => _MessageFormState();
}

class _MessageFormState extends State<MessageForm> {
  final controller = TextEditingController();

  Future<void> addMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'text': text,
      'createdAt': Timestamp.now(),
    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration:
            const InputDecoration(labelText: "Enter a message"),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: addMessage,
        ),
      ],
    );
  }
}

// ---------------------------
// REAL-TIME MESSAGE LIST
// ---------------------------
class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return MessageTile(
              id: doc.id,
              text: doc['text'],
            );
          },
        );
      },
    );
  }
}

// ---------------------------
// MESSAGE TILE (EDIT + DELETE)
// ---------------------------
class MessageTile extends StatelessWidget {
  final String id;
  final String text;

  const MessageTile({
    super.key,
    required this.id,
    required this.text,
  });

  void editMessage(BuildContext context) {
    final controller = TextEditingController(text: text);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Save"),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('messages')
                  .doc(id)
                  .update({'text': controller.text});
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> deleteMessage() async {
    await FirebaseFirestore.instance.collection('messages').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(text),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => editMessage(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deleteMessage,
          ),
        ],
      ),
    );
  }
}
