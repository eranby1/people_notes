import 'dart:convert'; // המרת תמונות לטקסט
import 'dart:typed_data'; // טיפול בבייטים של תמונה
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart'; // בחירת תמונה מהגלריה
import 'package:intl/intl.dart'; // לעיצוב תאריכים
import '../models/person_note.dart'; // שים לב לנתיב הזה - הוא חשוב!
import 'detail_screen.dart';

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

  // --- טעינת נתונים ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? peopleString = prefs.getString('people_list');

    if (peopleString != null) {
      try {
        List<dynamic> jsonList = jsonDecode(peopleString);
        setState(() {
          people = jsonList.map((json) => PersonNote.fromJson(json)).toList();
          filteredPeople = people;
          isLoading = false;
        });
      } catch (e) {
        debugPrint("Error loading data: $e");
        setState(() => isLoading = false);
      }
    } else {
      setState(() {
        isLoading = false;
        filteredPeople = [];
      });
    }
  }

  // --- שמירת נתונים ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(people.map((e) => e.toJson()).toList());
    await prefs.setString('people_list', encodedData);
  }

  // --- סינון וחיפוש ---
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

  // --- בחירת תמונה מהגלריה והמרה ל-Base64 ---
  Future<String?> _pickImageBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      ); // איכות מוקטנת לחסכון במקום

      if (image == null) return null;

      // קריאת הקובץ והמרה לטקסט
      Uint8List imageBytes = await image.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // --- הוספת איש קשר ---
  void _addPerson(String name, String phone, String? base64Image) {
    setState(() {
      PersonNote newPerson = PersonNote(
        name: name,
        phoneNumber: phone,
        notes: [],
        imageBase64: base64Image, // שימוש בשדה החדש
      );
      people.add(newPerson);
      _searchController.clear();
      isSearching = false;
      filteredPeople = people;
    });
    _saveData();
  }

  // --- מחיקת איש קשר ---
  void _deletePerson(PersonNote personToDelete) {
    int originalIndex = people.indexOf(personToDelete);
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
              people.insert(originalIndex, personToDelete);
              _runFilter(_searchController.text);
            });
            _saveData();
          },
        ),
      ),
    );
  }

  // --- וואטסאפ ---
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

  // --- ייבוא מאנשי הקשר (כולל תמונה!) ---
  Future<void> _pickContact(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    ValueNotifier<String?> imageNotifier,
  ) async {
    if (await FlutterContacts.requestPermission()) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        // משיכת פרטים מלאים כולל תמונה ברזולוציה גבוהה
        final fullContact = await FlutterContacts.getContact(
          contact.id,
          withPhoto: true,
        );

        setState(() {
          nameCtrl.text = contact.displayName;
          if (contact.phones.isNotEmpty) {
            phoneCtrl.text = contact.phones.first.number;
          }
          // אם יש תמונה לאיש הקשר, נמיר אותה ל-Base64
          if (fullContact?.photo != null) {
            imageNotifier.value = base64Encode(fullContact!.photo!);
          }
        });
      }
    }
  }

  // --- דיאלוג הוספה ---
  void _showAddPersonDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    // שימוש ב-ValueNotifier כדי לעדכן את התמונה בדיאלוג בלי לבנות את כולו מחדש
    ValueNotifier<String?> tempImageBase64 = ValueNotifier(null);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('איש קשר חדש'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // תצוגת תמונה
              ValueListenableBuilder<String?>(
                valueListenable: tempImageBase64,
                builder: (context, base64Img, child) {
                  Uint8List? bytes;
                  if (base64Img != null) {
                    try {
                      bytes = base64Decode(base64Img);
                    } catch (_) {}
                  }

                  return GestureDetector(
                    onTap: () async {
                      String? img = await _pickImageBase64();
                      if (img != null) {
                        tempImageBase64.value = img;
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: bytes != null
                          ? MemoryImage(bytes)
                          : null,
                      child: bytes == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 30,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'לחץ להוספת תמונה',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () => _pickContact(
                  nameController,
                  phoneController,
                  tempImageBase64,
                ),
                icon: const Icon(Icons.contacts),
                label: const Text('ייבא מאנשי קשר'),
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
                  tempImageBase64.value,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('צור'),
          ),
        ],
      ),
    );
  }

  // --- צבעים לאווטאר ברירת מחדל ---
  Color _getAvatarColor(String name) {
    if (name.isEmpty) return Colors.teal;
    return Colors.primaries[name.hashCode % Colors.primaries.length];
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

                // פענוח תמונה (אם יש)
                Uint8List? personImage;
                if (person.imageBase64 != null) {
                  try {
                    personImage = base64Decode(person.imageBase64!);
                  } catch (_) {}
                }

                // טקסט תחתון: תאריך ההערה האחרונה
                String subtitleText = '${person.notes.length} פתקים';
                if (person.notes.isNotEmpty) {
                  String date = DateFormat(
                    'dd/MM',
                  ).format(person.notes.last.date);
                  subtitleText += ' • אחרון ב-$date';
                }

                return Dismissible(
                  key: ValueKey(
                    person,
                  ), // שימוש ב-Object Key במקום String Key למניעת באגים
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("מחיקת איש קשר"),
                          content: Text("למחוק את ${person.name}?"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("ביטול"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
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
                      // תצוגת האווטאר המשופרת
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: _getAvatarColor(person.name),
                        backgroundImage: personImage != null
                            ? MemoryImage(personImage)
                            : null,
                        child: personImage == null
                            ? Text(
                                person.name.isNotEmpty ? person.name[0] : '?',
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Text(
                        person.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(subtitleText),
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
