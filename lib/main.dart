// GitHub-ready habit tracker Flutter app

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:html' as html;

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
  final AudioPlayer _audioPlayer = AudioPlayer();

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

    // Play sound based on streak using the html package
    if (streak % 28 == 0) {
      html.AudioElement audio = html.AudioElement('assets/sounds/reward28.wav');
      audio.play();
    } else if (streak % 7 == 0) {
      html.AudioElement audio = html.AudioElement('assets/sounds/reward7.wav');
      audio.play();
    } else {
      html.AudioElement audio = html.AudioElement('assets/sounds/click.ogg');
      audio.play();
    }

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

  String visualStreak(int streak) {
    final stars = streak ~/ 28;
    final flames = (streak % 28) ~/ 7;
    final sparkles = streak % 7;

    // Return the static part and the new emoji separately
    return '🌟' * stars + '🔥' * flames + '✨' * (sparkles - 1);
  }

  Widget animatedEmoji(int streak) {
    final sparkles = streak % 7;

    // Only animate the last added emoji
    if (sparkles > 0) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 500),
        child: Text(
          '✨',
          style: const TextStyle(fontSize: 18),
        ),
      );
    }
    return const SizedBox.shrink(); // No animation if no new emoji
  }

  Widget habitButton(String habit) {
    final streak = streaks[habit] ?? 0;
    final isDisabled = disabled[habit] ?? false;

    final streakColor = streak >= 100
        ? Colors.redAccent
        : streak >= 30
            ? Colors.deepOrange
            : streak >= 7
                ? Colors.amber
                : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: isDisabled ? null : () => markHabitDone(habit),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✔ $habit', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: streakColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: streak > 0
                        ? [
                            BoxShadow(
                              color: streakColor.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    '$streak',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🌟' * (streak ~/ 28) + '🔥' * ((streak % 28) ~/ 7) + '✨' * (streak % 7),
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (debugMode)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: SizedBox(
                width: 160,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Set streak (debug)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    final newStreak = int.tryParse(val);
                    if (newStreak != null) {
                      setState(() {
                        streaks[habit] = newStreak;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
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
