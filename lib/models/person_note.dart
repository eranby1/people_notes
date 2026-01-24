class PersonNote {
  String name;
  String phoneNumber;
  List<String> notes;
  String? imagePath;

  PersonNote({
    required this.name,
    required this.phoneNumber,
    required this.notes,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'notes': notes,
    'imagePath': imagePath,
  };

  factory PersonNote.fromJson(Map<String, dynamic> json) {
    return PersonNote(
      name: json['name'],
      phoneNumber: json['phoneNumber'] ?? '',
      notes: List<String>.from(json['notes']),
      imagePath: json['imagePath'],
    );
  }
}
