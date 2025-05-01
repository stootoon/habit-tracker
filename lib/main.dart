// GitHub-ready habit tracker Flutter app

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:audioplayers/audioplayers.dart';
//import 'dart:html' as html;
import 'package:confetti/confetti.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🔄 Firebase.apps.length = ${Firebase.apps.length}");
  print("🔍 Platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}");

  if (Firebase.apps.isEmpty) {
    if (kIsWeb) {
      print("🌐 Initializing Firebase for Web with options...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else if (Platform.isIOS) {
      print("🍎 Initializing Firebase for iOS with options...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      print("🤖 Initializing Firebase for Android (no options)...");
      await Firebase.initializeApp(); // ⚠️ Do NOT pass options here!
    }
  } else {
    print("✅ Firebase already initialized.");
  }

  print("🚀 Firebase initialized: ${Firebase.apps.first.name}");
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
  //final userId = 'demo_user';
  final String userId = const String.fromEnvironment('USER_ID', defaultValue: 'demo_user');

  int streakFreezes = 0; // Number of streak freezes the user has
  int kfcsEarned = 0;    // Number of KFCs earned by the user  

  final streakFreezeEvery = 3;
  final kfcEvery = 7;

  final intervals = [3, 7, 14, 30, 60, 90, 180, 365];
  final startColor = Colors.brown; // Start of interval
  final endColor = Colors.amber;  // End of interval (gold)

  Map<String, int> streaks = {};
  Map<String, String> lastCompleted = {};
  Map<String, bool> disabled = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> collectedBadges = [];
  final Map<String, ConfettiController> confettiControllers = {};
  DateTime currentDate = DateTime.now();
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    fetchStreaks().then((_) {
      checkAndApplyStreakFreezes();
    });

    cleanUpOldMessages();
    listenToMessages();

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

  Future<void> addMessage(String text) async {
    final message = {
      'text': text,
      'from': "system",
      'timestamp': DateTime.now().toIso8601String(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('messages')
        .add(message);
    print("Message added: $text from ${message['from']} at ${message['timestamp']}");
  }

  void listenToMessages() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((querySnapshot) {
          setState(() {
            messages = querySnapshot.docs.map((doc) {
              return {
                'text':doc['text'],
                'from': doc['from'],
                'timestamp': doc['timestamp'],
              };
            }).toList();
          });
        });
  }

  Future<void> cleanUpOldMessages() async {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('messages')
        .where('timestamp', isLessThan: oneWeekAgo.toIso8601String())
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
      print("Deleted old message: ${doc['text']} from ${doc['from']} at ${doc['timestamp']}");
    }
  }

  Future<void> fetchStreaks() async {
    final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          streakFreezes = userDoc.data()?['streakFreezes'] ?? 0;
          kfcsEarned = userDoc.data()?['kfcsEarned'] ?? 0;
        });
      }

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
          disabled[habit] = !kDebugMode && lastCompleted[habit] ==
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

    bool achievedInterval = false;
    bool achievedStreakFreeze = false;
    bool achievedKFC = false;

    // Check if achieved a badge
    for (var interval in intervals) {
      if (streak == interval) {
        achievedInterval = true;
      }
    }

      // Check if a streak freeze is earned
  if (streak % streakFreezeEvery == 0) {
          achievedStreakFreeze = true;  
    setState(() {
      streakFreezes = streakFreezes < 3 ? streakFreezes+1 : streakFreezes;

    });

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
      'streakFreezes': streakFreezes,
    }, SetOptions(merge: true));

    addMessage('🎉 You earned a streak freeze! Total: $streakFreezes');
  }

  // Check if a KFC is earned
  if (streak % kfcEvery == 0) {
          achievedKFC = true; 
    setState(() {
      kfcsEarned=1;

    });

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
      'kfcsEarned': kfcsEarned,
    }, SetOptions(merge: true));

    addMessage('🍗 You earned a KFC! Total: $kfcsEarned');
  }
    if (achievedKFC) {
      playAudio("yay_long.wav");
    } else if (achievedStreakFreeze) {
      playAudio("huzzah.wav");
    } else {
      // Play a random audio file
      playRandomAudio();
    }
  

    // Trigger confetti animation
    confettiControllers[habit]?.play();

    addMessage('✔ Logged $habit for today!');
  }

  void progressToNextDay() {
    setState(() {
      currentDate = currentDate.add(const Duration(days: 1));
      for (var habit in habits) {
        disabled[habit] = lastCompleted[habit] ==
          currentDate.toIso8601String().split('T')[0]; // Update disabled state
        //lastCompleted[habit] = ''; // Clear last completed
      }
    });
    checkAndApplyStreakFreezes();
  }

void playAudio(String assetName) async {
  final soundFile = "sounds/$assetName";
  // Play the audio using the browser's default audio playback
  //final audio = html.AudioElement(soundFile);
  //audio.play();

  print("Playing sound: $soundFile");
  try {
    await _audioPlayer.play(AssetSource(soundFile)); // Use AudioPlayer to play the asset
  } catch (e) {
    print("Error playing audio: $e");
  }
}  

void playRandomAudio() {
  // List of available audio files
  final audioFiles = [
   // 'assets/sounds/yay_short/yay_chipmunks.wav',
   // 'assets/sounds/yay_short/yay_enthusiastic.wav',
    'yay_short/yay_rat_fixed.mp3',
   // 'assets/sounds/yay_short/yay_small_group.wav',
   // 'assets/sounds/yay_short/youpi.wav',
  ];

  // Select a random file
  //randomFile = (audioFiles..shuffle()).first;
  //playAudio(randomFile);
  //final randomFile = "test.mp3";
  final randomFile = "yay_rat.mp3";
  playAudio(randomFile);
}
  Widget habitButton(String habit) {
    final streak = streaks[habit] ?? 0;
    final isDisabled = disabled[habit] ?? false;
    final isCompleted = lastCompleted[habit] == currentDate.toIso8601String().split('T')[0];
    final collectedBadges = intervals.where((interval) => streak > interval).toList();
    final habitText = kDebugMode
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
    // counter color should be end.color if streak is in collected badges else blue
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

void resetStreaks() async {
  for (var habit in habits) {
    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit)
        .set({
      'streak': 0,
      'last_completed': '',
    }, SetOptions(merge: true));

    // Update local state
    setState(() {
      streaks[habit] = 0;
      lastCompleted[habit] = '';
      disabled[habit] = false; // Re-enable all buttons
    });
  }

// Reset streak freezes and KFCs
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .set({
    'streakFreezes': 0,
    'kfcsEarned': 0,
  }, SetOptions(merge: true));

  setState(() {
    streakFreezes = 0;
    kfcsEarned = 0;
  });

  currentDate = DateTime.now();

  addMessage('✔ All streaks, streak freezes, and KFCs have been reset!');
  
}

void resetKFCs() async {
  // Update Firestore
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .set({
    'kfcsEarned': 0,
  }, SetOptions(merge: true));

  // Update local state
  setState(() {
    kfcsEarned = 0;
  });

  addMessage('🍗 All KFCs have been reset!');
}

Future<void> checkAndApplyStreakFreezes() async {
  final yesterday = currentDate.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

  for (var habit in habits) {
    final lastCompletedDate = lastCompleted[habit] ?? '';
    if (lastCompletedDate.isEmpty) continue;

    final lastCompletedDateTime = DateTime.parse(lastCompletedDate);
    final difference = currentDate.difference(lastCompletedDateTime).inDays;

    // Check if the streak is broken
    if (difference > 1) {
      if (streakFreezes > 0) {
        // Apply a streak freeze
        setState(() {
          streakFreezes--;
          lastCompleted[habit] = yesterday;
        });

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('habits')
            .doc(habit)
            .set({
          'last_completed': yesterday,
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
          'streakFreezes': streakFreezes,
        }, SetOptions(merge: true));

        // Play the "win_chimes" sound
        playAudio("win_chimes.wav");

        addMessage('❄️ Streak freeze applied to "$habit"!');
      } else {
        // Reset the streak to 0
        setState(() {
          streaks[habit] = 0;
          lastCompleted[habit] = '';
          disabled[habit] = false; // Re-enable the button
        });
        // No streak freezes available, streak is broken
        addMessage('⚠️ Streak broken for "$habit"!');
      }
    }
  }
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
        title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Hello $userId! Your habits on $dateFormat"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${streakFreezes > 0 ? '❄️' * streakFreezes : 'Streak Freezes: 0'} ",
                style: TextStyle(fontSize: streakFreezes > 0 ? 20 : 14),
              ),
              const SizedBox(width: 8),
              // Show drumstick emoji if KFCs > 0
              if (kfcsEarned > 0)
                GestureDetector(
                  onTap: resetKFCs, // Reset KFCs when pressed
                  child: const Text(
                    "🍗",
                    style: TextStyle(fontSize: 20),
                  ),
                )
              else
                Text(
                  "KFCs: $kfcsEarned",
                  style: const TextStyle(fontSize: 14),
                ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (kDebugMode) ...[
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: progressToNextDay,
            tooltip: "Progress to next day",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetStreaks,
            tooltip: "Reset all streaks",
          ),
        ],
      ],
    ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (var habit in habits) habitButton(habit),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        message['text'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
}
