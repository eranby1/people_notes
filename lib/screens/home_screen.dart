import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/person_note.dart'; // קישור למודל
import 'detail_screen.dart'; // קישור למסך הפרטים

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PersonNote> people = [];
  List<PersonNote> filteredPeople = [];
  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _runFilter(String enteredKeyword) {
    List<PersonNote> results = [];
    if (enteredKeyword.isEmpty) {
      results = people;
    } else {
      results = people
          .where(
            (person) => person.name.toLowerCase().contains(
              enteredKeyword.toLowerCase(),
            ),
          )
          .toList();
    }

    setState(() {
      filteredPeople = results;
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? peopleString = prefs.getString('people_list');

    if (peopleString != null) {
      List<dynamic> jsonList = jsonDecode(peopleString);
      setState(() {
        people = jsonList.map((json) => PersonNote.fromJson(json)).toList();
        filteredPeople = people;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
        filteredPeople = [];
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(people.map((e) => e.toJson()).toList());
    await prefs.setString('people_list', encodedData);
  }

  Future<String?> _pickAndSaveImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final String newPath = p.join(directory.path, p.basename(image.path));
      final File localImage = await File(image.path).copy(newPath);

      return localImage.path;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  void _addPerson(String name, String phone, String? imagePath) {
    setState(() {
      PersonNote newPerson = PersonNote(
        name: name,
        phoneNumber: phone,
        notes: [],
        imagePath: imagePath,
      );
      people.add(newPerson);
      _searchController.clear();
      isSearching = false;
      filteredPeople = people;
    });
    _saveData();
  }

  void _deletePerson(PersonNote personToDelete) {
    setState(() {
      people.remove(personToDelete);
      _runFilter(_searchController.text);
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${personToDelete.name} נמחק'),
        action: SnackBarAction(
          label: 'ביטול',
          onPressed: () {
            setState(() {
              people.add(personToDelete);
              _runFilter(_searchController.text);
            });
            _saveData();
          },
        ),
      ),
    );
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
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
  ) async {
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
    String? tempImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('איש קשר חדש'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    String? path = await _pickAndSaveImage();
                    if (path != null) {
                      setDialogState(() {
                        tempImagePath = path;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: tempImagePath != null
                        ? FileImage(File(tempImagePath!))
                        : null,
                    child: tempImagePath == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 30,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'לחץ להוספת תמונה',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () =>
                      _pickContact(nameController, phoneController),
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
                child: const Text('ביטול'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    _addPerson(
                      nameController.text,
                      phoneController.text,
                      tempImagePath,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('צור'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[100],
        title: !isSearching
            ? const Text('לדבר עם...')
            : TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.black),
                  hintText: "חפש שם...",
                  border: InputBorder.none,
                ),
                onChanged: (value) => _runFilter(value),
                autofocus: true,
              ),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  _searchController.clear();
                  _runFilter('');
                }
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredPeople.isEmpty
          ? Center(
              child: Text(
                people.isEmpty
                    ? 'הרשימה ריקה, הוסף מישהו!'
                    : 'לא נמצאו תוצאות ל"${_searchController.text}"',
              ),
            )
          : ListView.builder(
              itemCount: filteredPeople.length,
              itemBuilder: (context, index) {
                final person = filteredPeople[index];

                return Dismissible(
                  key: ValueKey(person),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("מחיקת איש קשר"),
                          content: Text(
                            "האם אתה בטוח שברצונך למחוק את ${person.name}?",
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
                  onDismissed: (direction) => _deletePerson(person),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: person.imagePath != null
                            ? FileImage(File(person.imagePath!))
                            : null,
                        child: person.imagePath == null
                            ? Text(
                                person.name.isNotEmpty ? person.name[0] : '?',
                              )
                            : null,
                      ),
                      title: Text(
                        person.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${person.notes.length} פתקים'),
                      trailing: person.phoneNumber.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.chat, color: Colors.green),
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
