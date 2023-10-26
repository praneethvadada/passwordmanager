import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PasswordManager(),
      theme: ThemeData(
        primaryColor: Colors.indigo,
        hintColor: Colors.indigoAccent,
      ),
    );
  }
}

class MyAppData {
  static List<Map<String, String>> passwordData = [];
  static TextEditingController handleNameController = TextEditingController();
  static TextEditingController userNameController = TextEditingController();
  static TextEditingController passwordController = TextEditingController();
  static List<int> selectedPasswords = [];
}

class PasswordManager extends StatefulWidget {
  @override
  _PasswordManagerState createState() => _PasswordManagerState();
}

class _PasswordManagerState extends State<PasswordManager> {
  @override
  void initState() {
    super.initState();
    loadPasswords();
  }

  void loadPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('passwordData') ?? [];

    MyAppData.passwordData = data.map((entry) {
      final parts = entry.split(',');
      return {
        'handleName': parts[0],
        'userName': parts[1],
        'password': parts[2],
      };
    }).toList();

    setState(() {});
  }

  void importPasswords() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path;

      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        final content = await file.readAsString();

        final csvData = const CsvToListConverter().convert(content);

        for (final row in csvData.skip(1)) {
          if (row.length == 3) {
            final handleName = row[0];
            final userName = row[1];
            final password = row[2];

            MyAppData.passwordData.add({
              'handleName': handleName,
              'userName': userName,
              'password': password,
            });
          }
        }

        final prefs = await SharedPreferences.getInstance();
        prefs.setStringList('passwordData', MyAppData.passwordData.map((entry) {
          return "${entry['handleName']},${entry['userName']},${entry['password']}";
        }).toList());

        setState(() {});
      }
    }
  }

  void savePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final entry =
        "${MyAppData.handleNameController.text},${MyAppData.userNameController.text},${MyAppData.passwordController.text}";
    MyAppData.passwordData.add({
      'handleName': MyAppData.handleNameController.text,
      'userName': MyAppData.userNameController.text,
      'password': MyAppData.passwordController.text,
    });

    prefs.setStringList(
        'passwordData', MyAppData.passwordData.map((entry) {
      return "${entry['handleName']},${entry['userName']},${entry['password']}";
    }).toList());

    MyAppData.handleNameController.clear();
    MyAppData.userNameController.clear();
    MyAppData.passwordController.clear();
    setState(() {});
  }

  void exportPasswords() async {
    if (MyAppData.passwordData.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('No Passwords to Export'),
            content: Text('There are no passwords to export.'),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    List<List<String>> csvData = [
      ['Handle Name', 'User Name', 'Password'],
      for (var entry in MyAppData.passwordData)
        [entry['handleName'] ?? 'N/A', entry['userName'] ?? 'N/A', entry['password'] ?? 'N/A'],
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/passwords.csv');
    await file.writeAsString(csv);

    Share.shareFiles([file.path], text: 'Password data in CSV format');
  }

  // Edit Password
  void editPassword(int index) async {
    final handleName = MyAppData.handleNameController.text;
    final userName = MyAppData.userNameController.text;
    final password = MyAppData.passwordController.text;

    final prefs = await SharedPreferences.getInstance();

    if (index < MyAppData.passwordData.length) {
      MyAppData.passwordData[index] = {
        'handleName': handleName,
        'userName': userName,
        'password': password,
      };
    } else {
      // Handle adding a new password here
      MyAppData.passwordData.add({
        'handleName': handleName,
        'userName': userName,
        'password': password,
      });
    }

    prefs.setStringList(
        'passwordData', MyAppData.passwordData.map((entry) {
      return "${entry['handleName']},${entry['userName']},${entry['password']}";
    }).toList());

    MyAppData.handleNameController.clear();
    MyAppData.userNameController.clear();
    MyAppData.passwordController.clear();

    setState(() {});
  }

  // Delete Password
  void deletePassword(int index) async {
    final prefs = await SharedPreferences.getInstance();
    if (index < MyAppData.passwordData.length) {
      MyAppData.passwordData.removeAt(index);
      prefs.setStringList(
          'passwordData', MyAppData.passwordData.map((entry) {
        return "${entry['handleName']},${entry['userName']},${entry['password']}";
      }).toList());
      setState(() {});
    }
  }

  // Delete Selected Passwords
  void deleteSelectedPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    // Sort selectedPasswords in descending order to prevent index issues.
    MyAppData.selectedPasswords.sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the selected passwords?'),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                for (final index in MyAppData.selectedPasswords) {
                  if (index < MyAppData.passwordData.length) {
                    MyAppData.passwordData.removeAt(index);
                  }
                }
                prefs.setStringList(
                    'passwordData', MyAppData.passwordData.map((entry) {
                  return "${entry['handleName']},${entry['userName']},${entry['password']}";
                }).toList());
                // Clear the selected passwords list.
                MyAppData.selectedPasswords.clear();
                Navigator.of(context).pop(); // Close the confirmation dialog.
                setState(() {});
              },
              child: Text('Delete'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the confirmation dialog.
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Password Manager'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Add Password'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: MyAppData.handleNameController,
                          decoration: InputDecoration(labelText: 'Handle Name'),
                        ),
                        TextField(
                          controller: MyAppData.userNameController,
                          decoration: InputDecoration(labelText: 'User Name'),
                        ),
                        TextField(
                          controller: MyAppData.passwordController,
                          decoration: InputDecoration(labelText: 'Password'),
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      ElevatedButton(
                        onPressed: () {
                          savePassword();
                          Navigator.of(context).pop();
                        },
                        child: Text('Save Password'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: exportPasswords,
          ),
          IconButton(
            icon: Icon(Icons.file_download),
            onPressed: importPasswords,
          ),
          if (MyAppData.selectedPasswords.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: deleteSelectedPasswords,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: MyAppData.passwordData.length,
        itemBuilder: (context, index) {
          return PasswordTile(
            handleName: MyAppData.passwordData[index]['handleName'],
            userName: MyAppData.passwordData[index]['userName'],
            password: MyAppData.passwordData[index]['password'],
            index: index,
            editPassword: editPassword,
            deletePassword: deletePassword,
            isSelected: MyAppData.selectedPasswords.contains(index),
            onLongPress: () {
              if (MyAppData.selectedPasswords.contains(index)) {
                MyAppData.selectedPasswords.remove(index);
              } else {
                MyAppData.selectedPasswords.add(index);
              }
              setState(() {});
            },
          );
        },
      ),
    );
  }
}

class PasswordTile extends StatelessWidget {
  final String? handleName;
  final String? userName;
  final String? password;
  final int index;
  final Function(int) editPassword;
  final Function(int) deletePassword;
  final bool isSelected;
  final VoidCallback onLongPress;

  PasswordTile({
    required this.handleName,
    required this.userName,
    required this.password,
    required this.index,
    required this.editPassword,
    required this.deletePassword,
    required this.isSelected,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.grey[300] : Colors.white,
      elevation: 3,
      margin: EdgeInsets.all(8),
      child: ListTile(
        title: Text(
          'Handle: ${handleName ?? "N/A"}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('User: ${userName ?? "N/A"}'),
        onLongPress: onLongPress,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Password for $handleName'),
                content: Text('Password: ${password ?? "N/A"}'),
                actions: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Edit button action
                      MyAppData.handleNameController.text = handleName ?? '';
                      MyAppData.userNameController.text = userName ?? '';
                      MyAppData.passwordController.text = password ?? '';

                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Edit Password'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                TextField(
                                  controller: MyAppData.handleNameController,
                                  decoration: InputDecoration(labelText: 'Handle Name'),
                                ),
                                TextField(
                                  controller: MyAppData.userNameController,
                                  decoration: InputDecoration(labelText: 'User Name'),
                                ),
                                TextField(
                                  controller: MyAppData.passwordController,
                                  decoration: InputDecoration(labelText: 'Password'),
                                ),
                              ],
                            ),
                            actions: <Widget>[
                              ElevatedButton(
                                onPressed: () {
                                  editPassword(index);
                                  Navigator.of(context).pop();
                                },
                                child: Text('Save Changes'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text('Edit'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Delete button action
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Delete Password'),
                            content: Text('Are you sure you want to delete this password?'),
                            actions: <Widget>[
                              ElevatedButton(
                                onPressed: () {
                                  deletePassword(index);
                                  Navigator.of(context).pop();
                                },
                                child: Text('Delete'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Cancel'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text('Delete'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
