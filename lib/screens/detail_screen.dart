import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/person_note.dart'; // הקישור לקובץ המודל

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
      widget.person.notes.add(content);
    });
  }

  void _editNote(int index, String newContent) {
    setState(() {
      widget.person.notes[index] = newContent;
    });
  }

  void _deleteNote(int index) {
    setState(() {
      widget.person.notes.removeAt(index);
    });
  }

  void _showEditNoteDialog(int index) {
    TextEditingController controller = TextEditingController(
      text: widget.person.notes[index],
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.person.imagePath != null)
              CircleAvatar(
                backgroundImage: FileImage(File(widget.person.imagePath!)),
                radius: 16,
              ),
            if (widget.person.imagePath != null) const SizedBox(width: 10),
            Text(widget.person.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditPersonDetailsDialog,
            tooltip: 'ערוך פרטי איש קשר',
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
                final noteContent = widget.person.notes[index];

                return Dismissible(
                  key: UniqueKey(),
                  background: Container(color: Colors.red),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("מחיקת פתק"),
                          content: const Text(
                            "האם אתה בטוח שברצונך למחוק את הפתק הזה?",
                          ),
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
                      title: Text(noteContent),
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
            backgroundColor: Colors.teal,
            onPressed: _listen,
            child: const Icon(Icons.mic, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _showAddNoteDialog,
            label: const Text('טקסט'),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
    );
  }
}
