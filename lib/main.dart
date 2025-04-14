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

  final intervals = [1, 3, 7, 14, 30, 60, 90, 180, 365];
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

    // Play a random audio file
    playRandomAudio();

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
        //lastCompleted[habit] = ''; // Clear last completed
      }
    });
  }

void playRandomAudio() {
  // List of available audio files
  final audioFiles = [
    'assets/sounds/yay_short/yay_chipmunks.wav',
    'assets/sounds/yay_short/yay_enthusiastic.wav',
    'assets/sounds/yay_short/yay_rat.wav',
    'assets/sounds/yay_short/yay_small_group.wav',
    'assets/sounds/yay_short/youpi.wav',
  ];

  // Select a random file
  final randomFile = (audioFiles..shuffle()).first;

  // Play the audio using the browser's default audio playback
  final audio = html.AudioElement(randomFile);
  audio.play();
}
  Widget habitButton(String habit) {
    final streak = streaks[habit] ?? 0;
    final isDisabled = disabled[habit] ?? false;
    final isCompleted = lastCompleted[habit] == currentDate.toIso8601String().split('T')[0];
    final collectedBadges = intervals.where((interval) => streak > interval).toList();
    final habitText = debugMode
        ? '$habit (Last completed: ${lastCompleted[habit] ?? "Never"})'
        : habit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          buildConfetti(habit),
          buildHabitContent(habitText, isDisabled, isCompleted, collectedBadges, streak, habit),
        ],
      ),
    );
  }

  Widget buildConfetti(String habit) {
    return ConfettiWidget(
      confettiController: confettiControllers[habit]!,
      blastDirectionality: BlastDirectionality.explosive,
      shouldLoop: false,
      colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
    );
  }

  Widget buildHabitContent(
    String habitText,
    bool isDisabled,
    bool isCompleted,
    List<int> collectedBadges,
    int streak,
    String habit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildHabitRow(habitText, isDisabled, isCompleted, habit),
        const SizedBox(height: 8),
        buildBadgesAndStreak(collectedBadges, streak),
      ],
    );
  }

  Widget buildHabitRow(String habitText, bool isDisabled, bool isCompleted, String habit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isDisabled ? null : () => markHabitDone(habit),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: isDisabled ? Colors.grey : null,
            ),
            child: Text(
              habitText,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
          color: isCompleted ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget buildBadgesAndStreak(List<int> collectedBadges, int streak) {
    return Row(
      children: [
        for (var badge in collectedBadges)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: endColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$streak',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the date in 2 April 2023 format
    // Use a month string instead of a number
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[currentDate.month - 1];
    final dateFormat = "${currentDate.day} ${month} ${currentDate.year}";
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Habits on $dateFormat (debugMode: $debugMode)"),
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
