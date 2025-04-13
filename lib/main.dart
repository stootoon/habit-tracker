// GitHub-ready habit tracker Flutter app

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(HabitApp());
}

class HabitApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HabitHomePage(),
    );
  }
}

class HabitHomePage extends StatefulWidget {
  @override
  _HabitHomePageState createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage> {
  final habits = ['Eat Vegetables', 'Walk'];
  final userId = 'demo_user';
  final bool debugMode = true;

  final rewards = {
    7: '🎉 Weekly Reward: You earned an ice cream!',
    30: '🏆 Monthly Reward: You earned fried chicken!'
  };

  Map<String, int> streaks = {};
  Map<String, String> lastCompleted = {};
  Map<String, bool> disabled = {};

  @override
  void initState() {
    super.initState();
    fetchStreaks();
  }

  Future<void> fetchStreaks() async {
    for (var habit in habits) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(habit)
          .get();

      if (doc.exists) {
        setState(() {
          streaks[habit] = doc['streak'] ?? 0;
          lastCompleted[habit] = doc['last_completed'] ?? '';
          disabled[habit] = !debugMode && lastCompleted[habit] ==
              DateTime.now().toIso8601String().split('T')[0];
        });
      } else {
        setState(() {
          streaks[habit] = 0;
          disabled[habit] = false;
        });
      }
    }
  }

  Future<void> markHabitDone(String habit) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit);

    final snapshot = await doc.get();
    int streak = 1;
    if (snapshot.exists && snapshot.data()!.containsKey('streak')) {
      streak = snapshot['streak'] + 1;
    }

    await doc.set({
      'last_completed': today,
      'streak': streak,
    }, SetOptions(merge: true));

    setState(() {
      streaks[habit] = streak;
      lastCompleted[habit] = today;
      disabled[habit] = !debugMode && lastCompleted[habit] == today;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✔ Logged $habit for today!')),
    );

    if (rewards.containsKey(streak)) {
      final rewardMessage = rewards[streak]!;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Reward Unlocked!'),
          content: Text(rewardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Nice!'),
            )
          ],
        ),
      );
    }
  }

  Widget habitButton(String habit) {
    final streak = streaks[habit] ?? 0;
    final isDisabled = disabled[habit] ?? false;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ElevatedButton(
        onPressed: isDisabled ? null : () => markHabitDone(habit),
        style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(60)),
        child: Text('✔ $habit (Streak: $streak)', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Habits")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (var habit in habits) habitButton(habit),
        ],
      ),
    );
  }
}
