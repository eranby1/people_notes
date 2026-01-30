import 'dart:convert';

// מודל לפתק בודד (טקסט + תאריך יצירה + תאריך תזכורת)
class NoteItem {
  String content;
  DateTime date;
  DateTime? reminderDate; // שדה חדש: מתי להזכיר? (יכול להיות ריק)

  NoteItem({required this.content, required this.date, this.reminderDate});

  // המרה ל-JSON
  Map<String, dynamic> toJson() => {
    'content': content,
    'date': date.toIso8601String(),
    // שומרים את התזכורת רק אם היא קיימת
    if (reminderDate != null) 'reminderDate': reminderDate!.toIso8601String(),
  };

  // טעינה מ-JSON
  factory NoteItem.fromJson(dynamic json) {
    if (json is String) {
      return NoteItem(content: json, date: DateTime.now());
    }
    return NoteItem(
      content: json['content'],
      date: DateTime.parse(json['date']),
      // טעינת התזכורת (אם יש)
      reminderDate: json['reminderDate'] != null
          ? DateTime.parse(json['reminderDate'])
          : null,
    );
  }
}

// המודל הראשי לאיש קשר (ללא שינוי, אבל מעתיק ליתר ביטחון)
class PersonNote {
  String name;
  String phoneNumber;
  List<NoteItem> notes;
  String? imageBase64;

  PersonNote({
    required this.name,
    required this.phoneNumber,
    required this.notes,
    this.imageBase64,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'notes': notes.map((n) => n.toJson()).toList(),
    'imageBase64': imageBase64,
  };

  factory PersonNote.fromJson(Map<String, dynamic> json) {
    var notesList = json['notes'] as List;
    List<NoteItem> parsedNotes = notesList.map((noteJson) {
      return NoteItem.fromJson(noteJson);
    }).toList();

    return PersonNote(
      name: json['name'],
      phoneNumber: json['phoneNumber'] ?? '',
      notes: parsedNotes,
      imageBase64: json['imageBase64'],
    );
  }
}
