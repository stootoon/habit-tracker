// GitHub-ready habit tracker Flutter app

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:html' as html;
import 'package:confetti/confetti.dart';

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
  final habits = ['Eat Vegetables', 'Walk Around the Block'];
  final userId = 'demo_user';
  final bool debugMode = true;

  final rewards = {
    7: '🎉 Weekly Reward: You earned an ice cream!',
    30: '🏆 Monthly Reward: You earned fried chicken!'
  };

  final intervals = [7, 14, 30, 60, 90, 180, 365];
  final startColor = Colors.brown; // Start of interval
  final endColor = Colors.amber;  // End of interval (gold)

  Map<String, int> streaks = {};
  Map<String, String> lastCompleted = {};
  Map<String, bool> disabled = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> collectedBadges = [];
  final Map<String, ConfettiController> confettiControllers = {};
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchStreaks();

    // Initialize a ConfettiController for each habit
    for (var habit in habits) {
      confettiControllers[habit] = ConfettiController(duration: const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    // Dispose of all ConfettiControllers
    for (var controller in confettiControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              currentDate.toIso8601String().split('T')[0];
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
    final today = currentDate.toIso8601String().split('T')[0];
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
      disabled[habit] = true; // Disable the button after marking as done
    });

    // Trigger confetti animation
    confettiControllers[habit]?.play();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✔ Logged $habit for today!')),
    );
  }

  void progressToNextDay() {
    setState(() {
      currentDate = currentDate.add(const Duration(days: 1));
      for (var habit in habits) {
        disabled[habit] = false; // Re-enable all buttons
        lastCompleted[habit] = ''; // Clear last completed
      }
    });
  }

  Widget habitButton(String habit) {
    final streak = streaks[habit] ?? 0;
    final isDisabled = disabled[habit] ?? false;
    final isCompleted = lastCompleted[habit] == currentDate.toIso8601String().split('T')[0];

    // Dynamically calculate collected badges (up to the previous day)
    final collectedBadges = intervals.where((interval) => streak > interval).toList();

    // Append last completed date if in debug mode
    final habitText = debugMode
        ? '$habit (Last completed: ${lastCompleted[habit] ?? "Never"})'
        : habit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align everything to the left
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start, // Align button and checkmark horizontally
            children: [
              // Habit button
              Expanded(
                child: ElevatedButton(
                  onPressed: isDisabled ? null : () => markHabitDone(habit),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: isDisabled ? Colors.grey : null, // Gray out if disabled
                  ),
                  child: Text(
                    habitText,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Checkbox for completion status
              Icon(
                isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                color: isCompleted ? Colors.green : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Display collected badges and streak counter
          Row(
            children: [
              // Badges
              for (var badge in collectedBadges)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: endColor, // Gold for completed badges
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              // Streak counter
              Container(
                margin: const EdgeInsets.only(left: 8), // Add spacing after badges
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue, // Use a distinct color for the streak counter
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$streak',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Habits (debugMode: $debugMode)"),
        actions: [
          if (debugMode)
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: progressToNextDay,
              tooltip: "Progress to next day",
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
           padding: const EdgeInsets.all(20),
           children: [
            for (var habit in habits) habitButton(habit),
           ],
          ),
      ),
    ),
  );
}
}
