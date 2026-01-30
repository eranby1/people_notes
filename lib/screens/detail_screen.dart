import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import '../models/person_note.dart';
import '../notification_service.dart'; // חשוב: קישור לשירות ההתראות

class PersonDetailScreen extends StatefulWidget {
  final PersonNote person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _liveText = "";

  @override
  void initState() {
    super.initState();
  }

  // --- לוגיקה של תזכורות ---
  Future<void> _pickReminderTime(int index, NoteItem note) async {
    // 1. בחירת תאריך
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // 2. בחירת שעה
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    // 3. איחוד לתאריך שלם
    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 4. שמירה ותזמון
    setState(() {
      note.reminderDate = finalDateTime;
    });

    // יצירת מזהה ייחודי להתראה (משתמשים בקוד ההאש של האובייקט)
    int notificationId = note.hashCode;

    await NotificationService().scheduleNoteReminder(
      notificationId,
      'תזכורת: ${widget.person.name}',
      note.content,
      finalDateTime,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'תזכורת נקבעה ל-${DateFormat('dd/MM HH:mm').format(finalDateTime)}',
        ),
      ),
    );
  }

  void _cancelReminder(NoteItem note) async {
    int notificationId = note.hashCode;
    await NotificationService().cancelNotification(notificationId);

    setState(() {
      note.reminderDate = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('התזכורת בוטלה')));
  }

  // --- לוגיקה קיימת ---

  void _saveAndClose() {
    if (!mounted) return;
    _speech.stop();
    if (_isListening && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() {
      _isListening = false;
    });
    if (_liveText.isNotEmpty && _liveText != "מקשיב...") {
      _addNote(_liveText);
    }
  }

  void _listen() async {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );

    if (available) {
      setState(() {
        _isListening = true;
        _liveText = "מקשיב...";
      });
      _showListeningDialog();
      _speech.listen(
        onResult: (val) {
          setState(() {
            _liveText = val.recognizedWords;
          });
          if (val.finalResult) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _saveAndClose();
            });
          }
        },
        localeId: 'he_IL',
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('זיהוי דיבור לא זמין או אין הרשאה')),
      );
    }
  }

  void _showListeningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.mic, color: Colors.red),
                  SizedBox(width: 10),
                  Text("מקליט..."),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _liveText.isEmpty ? "דבר עכשיו..." : _liveText,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "(ההקלטה תסתיים אוטומטית אחרי 3 שניות של שקט)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _speech.stop();
                    setState(() => _isListening = false);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "ביטול",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  onPressed: _saveAndClose,
                  child: const Text("סיום"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNote(String content) {
    setState(() {
      widget.person.notes.add(NoteItem(content: content, date: DateTime.now()));
    });
  }

  void _editNote(int index, String newContent) {
    setState(() {
      widget.person.notes[index].content = newContent;
    });
  }

  void _deleteNote(int index) {
    // אם יש תזכורת, צריך לבטל אותה לפני המחיקה
    if (widget.person.notes[index].reminderDate != null) {
      _cancelReminder(widget.person.notes[index]);
    }
    setState(() {
      widget.person.notes.removeAt(index);
    });
  }

  void _showEditNoteDialog(int index) {
    TextEditingController controller = TextEditingController(
      text: widget.person.notes[index].content,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ערוך פתק'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _editNote(index, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('מה רצית להגיד ל${widget.person.name}?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addNote(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('הוסף פתק'),
          ),
        ],
      ),
    );
  }

  void _showEditPersonDetailsDialog() {
    TextEditingController nameCtrl = TextEditingController(
      text: widget.person.name,
    );
    TextEditingController phoneCtrl = TextEditingController(
      text: widget.person.phoneNumber,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרטי איש קשר'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'שם'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'טלפון'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                widget.person.name = nameCtrl.text;
                widget.person.phoneNumber = phoneCtrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text('שמור שינויים'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? personImage;
    if (widget.person.imageBase64 != null) {
      try {
        personImage = base64Decode(widget.person.imageBase64!);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (personImage != null)
              CircleAvatar(
                backgroundImage: MemoryImage(personImage),
                radius: 16,
              ),
            if (personImage != null) const SizedBox(width: 10),
            Text(widget.person.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditPersonDetailsDialog,
          ),
        ],
      ),
      body: widget.person.notes.isEmpty
          ? Center(
              child: Text(
                'הכל ריק! אין לך מה להגיד ל${widget.person.name}?',
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: widget.person.notes.length,
              itemBuilder: (context, index) {
                final note = widget.person.notes[index];
                String formattedDate = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(note.date);

                // האם יש תזכורת פעילה?
                bool hasReminder =
                    note.reminderDate != null &&
                    note.reminderDate!.isAfter(DateTime.now());
                String? reminderText;
                if (hasReminder) {
                  reminderText = DateFormat(
                    'dd/MM HH:mm',
                  ).format(note.reminderDate!);
                }

                return Dismissible(
                  key: UniqueKey(),
                  background: Container(color: Colors.red),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("מחיקת פתק"),
                          content: const Text("האם למחוק את הפתק?"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("ביטול"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                "מחק",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) => _deleteNote(index),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(note.content),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (hasReminder)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.alarm,
                                    size: 14,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "תזכורת: $reminderText",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      // כפתור הפעמון החדש
                      trailing: IconButton(
                        icon: Icon(
                          hasReminder
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: hasReminder ? Colors.teal : Colors.grey,
                        ),
                        onPressed: () {
                          if (hasReminder) {
                            // אם כבר יש, לחיצה תציע לבטל או לשנות
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('ניהול תזכורת'),
                                content: Text('יש תזכורת ל-$reminderText'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _cancelReminder(note);
                                    },
                                    child: const Text(
                                      'בטל תזכורת',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _pickReminderTime(index, note);
                                    },
                                    child: const Text('שנה זמן'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // אם אין, קבע חדשה
                            _pickReminderTime(index, note);
                          }
                        },
                      ),
                      onTap: () => _showEditNoteDialog(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "micBtn",
            backgroundColor: Colors.teal,
            onPressed: _listen,
            child: const Icon(Icons.mic, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "textBtn",
            onPressed: _showAddNoteDialog,
            label: const Text('טקסט'),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
    );
  }
}
