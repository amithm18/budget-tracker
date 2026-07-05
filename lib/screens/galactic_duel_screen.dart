import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/antigravity_background.dart';
import '../widgets/glassmorphic_card.dart';
import 'add_expense_screen.dart';

class GalacticDuelScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;

  const GalacticDuelScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  @override
  State<GalacticDuelScreen> createState() => _GalacticDuelScreenState();
}

class _GalacticDuelScreenState extends State<GalacticDuelScreen> {
  late List<Member> _members;
  Member? _player1;
  Member? _player2;
  double _duelAmount = 500.0;
  String _expenseTitle = "Contested Sandwich";

  // Game state
  bool _isDuelStarted = false;
  bool _isCountingDown = false;
  bool _isPlaying = false;
  bool _isFinished = false;

  int _countdown = 3;
  int _player1Taps = 0;
  int _player2Taps = 0;
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _members = widget.controller.getMembersForGroup(widget.groupId);
    if (_members.length >= 2) {
      _player1 = _members[0];
      _player2 = _members[1];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (_player1 == null || _player2 == null || _player1!.id == _player2!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select two different celestial combatants!")),
      );
      return;
    }

    setState(() {
      _isDuelStarted = true;
      _isCountingDown = true;
      _countdown = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _startGame();
      }
    });
  }

  void _startGame() {
    setState(() {
      _isCountingDown = false;
      _isPlaying = true;
      _player1Taps = 0;
      _player2Taps = 0;
      _secondsLeft = 5;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isPlaying = false;
          _isFinished = true;
        });
      }
    });
  }

  void _resetGame() {
    setState(() {
      _isDuelStarted = false;
      _isCountingDown = false;
      _isPlaying = false;
      _isFinished = false;
      _player1Taps = 0;
      _player2Taps = 0;
    });
  }

  Member? get _winner => _player1Taps > _player2Taps
      ? _player1
      : (_player2Taps > _player1Taps ? _player2 : null);

  Member? get _loser => _player1Taps > _player2Taps
      ? _player2
      : (_player2Taps > _player1Taps ? _player1 : null);

  @override
  Widget build(BuildContext context) {
    if (_isDuelStarted) {
      return Scaffold(
        body: Container(
          color: AppTheme.bgDark,
          child: SafeArea(
            child: _buildGameUI(),
          ),
        ),
      );
    }

    // Settings Setup View
    return Scaffold(
      appBar: AppBar(
        title: const Text("Galactic Duel"),
      ),
      body: AntigravityBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassmorphicCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 60,
                        color: AppTheme.primaryLight,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Celestial Combat Arena",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Split disputes with speed. Tap as fast as you can. The loser gets stuck paying the bill!",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Player Selection
                GlassmorphicCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Choose Combatants",
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Member>(
                        value: _player1,
                        dropdownColor: AppTheme.bgSurface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: "Player 1 (Top Side)"),
                        items: _members.map((m) {
                          return DropdownMenuItem<Member>(
                            value: m,
                            child: Text(m.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _player1 = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Member>(
                        value: _player2,
                        dropdownColor: AppTheme.bgSurface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: "Player 2 (Bottom Side)"),
                        items: _members.map((m) {
                          return DropdownMenuItem<Member>(
                            value: m,
                            child: Text(m.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _player2 = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contested Bill Info
                GlassmorphicCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Wager / Contested Bill Details",
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _expenseTitle,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: "Expense Name"),
                        onChanged: (val) {
                          _expenseTitle = val;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _duelAmount.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Amount (${widget.controller.currency})",
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            _duelAmount = parsed;
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Start Action Button
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _startCountdown,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: const Text("Enter Arena"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    if (_isCountingDown) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "DUEL INCOMING IN",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "$_countdown",
              style: const TextStyle(
                color: AppTheme.primaryLight,
                fontSize: 120,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (_isPlaying) {
      return Column(
        children: [
          // Player 1 Tap Area (Top - Reversed/Rotated 180 degrees so players can face each other across a phone)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _player1Taps++;
                });
              },
              child: Container(
                width: double.infinity,
                color: AppTheme.primary.withOpacity(0.2),
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _player1?.name ?? "Player 1",
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "$_player1Taps",
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "TAP HERE!",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Central Timer/Divider
          Container(
            height: 60,
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$_secondsLeft SECONDS LEFT",
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Player 2 Tap Area (Bottom - Standard Orientation)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _player2Taps++;
                });
              },
              child: Container(
                width: double.infinity,
                color: AppTheme.secondary.withOpacity(0.2),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _player2?.name ?? "Player 2",
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$_player2Taps",
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "TAP HERE!",
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_isFinished) {
      final isDraw = _player1Taps == _player2Taps;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              const Text(
                "DUEL CONCLUDED",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDraw
                    ? "It's a Cosmic Draw!"
                    : "${_winner?.name} has won!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Score details card
              GlassmorphicCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "${_player1?.name}: $_player1Taps Taps",
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${_player2?.name}: $_player2Taps Taps",
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Action buttons
              if (!isDraw)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to details
                      // Route to AddExpense with prefilled loser
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddExpenseScreen(
                            controller: widget.controller,
                            groupId: widget.groupId,
                            prefilledPayerId: _loser?.id,
                            prefilledTitle: _expenseTitle,
                            prefilledAmount: _duelAmount,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text("Assign ${widget.controller.currency}$_duelAmount Bill to ${_loser?.name}"),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _resetGame,
                child: const Text("Rematch"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Exit Arena"),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }
}
