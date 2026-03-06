import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '娇姐复习专用', // 修改这里
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const QuizPage(),
    );
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<dynamic> allQuestions = [];
  int currentIndex = 0;
  bool isLoaded = false;
  String errorMessage = "";

  bool hasSubmitted = false;
  List<int> userSelectedIndices = [];

  @override
  void initState() {
    super.initState();
    _loadExamData();
  }

  Future<void> _loadExamData() async {
    setState(() { isLoaded = false; errorMessage = ""; });
    try {
      final String response = await rootBundle.loadString('assets/questions.json');
      final List<dynamic> data = json.decode(response);

      List<dynamic> singles = [];
      List<dynamic> multis = [];
      List<dynamic> judges = [];

      for (var item in data) {
        // 注意：这里匹配你 JSON 里的 "title" 字段
        if (item['title'] == null || item['type'] == null) continue;

        String t = item['type'].toString().trim();
        if (t == "单选题") {
          singles.add(item);
        } else if (t == "多选题") {
          multis.add(item);
        } else if (t == "判断题") {
          if (item['options'] == null || (item['options'] as List).isEmpty) {
            item['options'] = ["正确", "错误"];
          }
          judges.add(item);
        }
      }

      singles.shuffle();
      multis.shuffle();
      judges.shuffle();

      setState(() {
        allQuestions = [
          ...singles.take(40),
          ...multis.take(20),
          ...judges.take(20),
        ];
        isLoaded = true;
      });
    } catch (e) {
      setState(() {
        errorMessage = "加载失败: $e";
        isLoaded = true;
      });
    }
  }

  void _handleTap(int index, bool isMulti) {
    if (hasSubmitted) return;
    setState(() {
      if (isMulti) {
        if (userSelectedIndices.contains(index)) {
          userSelectedIndices.remove(index);
        } else {
          userSelectedIndices.add(index);
        }
      } else {
        userSelectedIndices = [index];
        hasSubmitted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allQuestions.isEmpty) return Scaffold(body: Center(child: Text(errorMessage.isEmpty ? "未找到题目" : errorMessage)));

    final question = allQuestions[currentIndex];
    final List<dynamic> options = question['options'] ?? [];
    final List<int> correctAnswers = List<int>.from(question['answer'] ?? []);
    bool isMulti = question['type'] == "多选题";

    return Scaffold(
      appBar: AppBar(title: Text("复习 (${currentIndex + 1}/${allQuestions.length})")),
      body: Column(
        children: [
          LinearProgressIndicator(value: (currentIndex + 1) / allQuestions.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("[${question['type']}]", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // 这里修改为显示 title
                Text(
                    question['title'] ?? "题目内容为空",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 20),
                ...List.generate(options.length, (index) => _buildOption(index, options[index], correctAnswers, isMulti)),
              ],
            ),
          ),
          _buildBottomBar(isMulti),
        ],
      ),
    );
  }

  Widget _buildOption(int index, String text, List<int> corrects, bool isMulti) {
    bool selected = userSelectedIndices.contains(index);
    bool isCorrect = corrects.contains(index);
    Color color = Colors.black87;
    IconData? icon;

    if (hasSubmitted) {
      if (isCorrect) {
        color = Colors.green;
        icon = Icons.check_circle;
      } else if (selected) {
        color = Colors.red;
        icon = Icons.cancel;
      }
    } else if (selected) {
      color = Colors.blue;
    }

    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Text(String.fromCharCode(65 + index), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        title: Text(text, style: TextStyle(color: color)),
        trailing: Icon(icon, color: color),
        onTap: () => _handleTap(index, isMulti),
      ),
    );
  }

  Widget _buildBottomBar(bool isMulti) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isMulti && !hasSubmitted)
            ElevatedButton(
              onPressed: userSelectedIndices.isEmpty ? null : () => setState(() => hasSubmitted = true),
              child: const Text("确认多选"),
            )
          else
            const SizedBox(),
          if (hasSubmitted)
            ElevatedButton(
              onPressed: () => setState(() {
                if (currentIndex < allQuestions.length - 1) {
                  currentIndex++;
                  hasSubmitted = false;
                  userSelectedIndices = [];
                } else {
                  _showCompleteDialog();
                }
              }),
              child: const Text("下一题"),
            ),
        ],
      ),
    );
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("本组练习结束"),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(c);
            _loadExamData();
            setState(() { currentIndex=0; hasSubmitted=false; userSelectedIndices=[]; });
          }, child: const Text("再来一组")),
        ],
      ),
    );
  }
}
