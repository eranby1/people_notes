import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

void main() {
  runApp(const PeopleNotesApp());
}

class PersonNote {
  String name;
  String phoneNumber;
  List<String> notes;

  PersonNote({
    required this.name,
    required this.phoneNumber,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phoneNumber': phoneNumber,
        'notes': notes,
      };

  factory PersonNote.fromJson(Map<String, dynamic> json) {
    return PersonNote(
      name: json['name'],
      phoneNumber: json['phoneNumber'] ?? '',
      notes: List<String>.from(json['notes']),
    );
  }
}

class PeopleNotesApp extends StatelessWidget {
  const PeopleNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'People Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PersonNote> people = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? peopleString = prefs.getString('people_list');

    if (peopleString != null) {
      List<dynamic> jsonList = jsonDecode(peopleString);
      setState(() {
        people = jsonList.map((json) => PersonNote.fromJson(json)).toList();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(people.map((e) => e.toJson()).toList());
    await prefs.setString('people_list', encodedData);
  }

  void _addPerson(String name, String phone) {
    setState(() {
      people.add(PersonNote(name: name, phoneNumber: phone, notes: []));
    });
    _saveData();
  }

  void _deletePerson(int index) {
    PersonNote deleted = people[index];
    setState(() {
      people.removeAt(index);
    });
    _saveData();

    // השארתי את ה-UNDO למקרה שהמשתמש יתחרט גם אחרי האישור
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${deleted.name} נמחק'),
      action: SnackBarAction(
        label: 'ביטול',
        onPressed: () {
          setState(() {
            people.insert(index, deleted);
          });
          _saveData();
        },
      ),
    ));
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '972${cleanPhone.substring(1)}';
    }
    final Uri url = Uri.parse("https://wa.me/$cleanPhone");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _pickContact(
      TextEditingController nameCtrl, TextEditingController phoneCtrl) async {
    if (await FlutterContacts.requestPermission()) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          nameCtrl.text = contact.displayName;
          if (contact.phones.isNotEmpty) {
            phoneCtrl.text = contact.phones.first.number;
          }
        });
      }
    }
  }

  void _showAddPersonDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('איש קשר חדש'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickContact(nameController, phoneController),
              icon: const Icon(Icons.contacts),
              label: const Text('ייבא מאנשי קשר בנייד'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'שם',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'טלפון',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addPerson(nameController.text, phoneController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('צור'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('לדבר עם...'), backgroundColor: Colors.teal[100]),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : people.isEmpty
              ? const Center(child: Text('הרשימה ריקה, הוסף מישהו!'))
              : ListView.builder(
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    
                    // --- שינוי: הוספת confirmDismiss ---
                    return Dismissible(
                      key: UniqueKey(),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.startToEnd,
                      
                      // זה הקוד החדש ששואל לפני מחיקה
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("מחיקת איש קשר"),
                              content: Text(
                                  "האם אתה בטוח שברצונך למחוק את ${person.name}?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("ביטול"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
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
                      onDismissed: (direction) => _deletePerson(index),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                              child: Text(person.name.isNotEmpty
                                  ? person.name[0]
                                  : '?')),
                          title: Text(person.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${person.notes.length} נושאים לשיחה'),
                          trailing: person.phoneNumber.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.chat,
                                      color: Colors.green),
                                  onPressed: () =>
                                      _launchWhatsApp(person.phoneNumber),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PersonDetailScreen(person: person),
                              ),
                            ).then((_) {
                              setState(() {});
                              _saveData();
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class PersonDetailScreen extends StatefulWidget {
  final PersonNote person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
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
    TextEditingController controller =
        TextEditingController(text: widget.person.notes[index]);
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
              child: const Text('ביטול')),
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
              child: const Text('ביטול')),
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
    TextEditingController nameCtrl =
        TextEditingController(text: widget.person.name);
    TextEditingController phoneCtrl =
        TextEditingController(text: widget.person.phoneNumber);

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
              child: const Text('ביטול')),
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
        title: Text(widget.person.name),
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
                final note = widget.person.notes[index];
                
                // --- שינוי: הוספת confirmDismiss גם בפתקים ---
                return Dismissible(
                  key: UniqueKey(),
                  background: Container(color: Colors.red),
                  
                  // דיאלוג אישור מחיקת פתק
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("מחיקת פתק"),
                          content: const Text(
                              "האם אתה בטוח שברצונך למחוק את הפתק הזה?"),
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
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(note),
                      onTap: () => _showEditNoteDialog(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        label: const Text('הוסף נושא'),
        icon: const Icon(Icons.add_comment),
      ),
    );
  }
} 