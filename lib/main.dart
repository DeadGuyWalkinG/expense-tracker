import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    final name = reader.readString();
    final amount = reader.readDouble();
    final dateMillis = reader.readInt();
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    return Expense(name: name, amount: amount, date: date);
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class Expense {
  final String name;
  final double amount;
  final DateTime date;

  Expense({required this.name, required this.amount, required this.date});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());
  await Hive.openBox<Expense>('expenses');
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Jost'),
          bodyMedium: TextStyle(fontFamily: 'Jost'),
          bodySmall: TextStyle(fontFamily: 'Jost'),
          displayLarge: TextStyle(fontFamily: 'Jost'),
          displayMedium: TextStyle(fontFamily: 'Jost'),
          displaySmall: TextStyle(fontFamily: 'Jost'),
          headlineLarge: TextStyle(fontFamily: 'Jost'),
          headlineMedium: TextStyle(fontFamily: 'Jost'),
          headlineSmall: TextStyle(fontFamily: 'Jost'),
          labelLarge: TextStyle(fontFamily: 'Jost'),
          labelMedium: TextStyle(fontFamily: 'Jost'),
          labelSmall: TextStyle(fontFamily: 'Jost'),
          titleLarge: TextStyle(fontFamily: 'Jost'),
          titleMedium: TextStyle(fontFamily: 'Jost'),
          titleSmall: TextStyle(fontFamily: 'Jost'),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.tealAccent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Jost',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        colorScheme:
            ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          brightness: Brightness.dark,
          secondary: Colors.tealAccent,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
        ),
      ),
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _errorText;

  Box<Expense> expensesBox = Hive.box<Expense>('expenses');
  int expenseLimit = 500;
  int _barChartStartIndex = 0;
  final int _visibleBars = 5;
  bool _isDeleteMode = false;

  // Calculate horizontal margin for buttons
  final double _buttonHorizontalMargin = 20.0;

  Map<String, List<Expense>> get _groupedExpenses {
    final Map<String, List<Expense>> grouped = {};
    final expenses = expensesBox.values.toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));

    for (var expense in expenses) {
      final dateKey = DateFormat.yMMMd().format(expense.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(expense);
    }
    return grouped;
  }

  Map<String, double> get _dailyExpensesData {
    final dailyTotals = <String, double>{};
    final expenses = expensesBox.values.toList();

    for (var expense in expenses) {
      final dateKey = DateFormat.MMMd().format(expense.date);
      dailyTotals.update(dateKey, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }

    final sortedDailyTotals = Map.fromEntries(dailyTotals.entries.toList()
      ..sort((e1, e2) => DateFormat.MMMd()
          .parse(e1.key)
          .compareTo(DateFormat.MMMd().parse(e2.key))));
    return sortedDailyTotals;
  }

  Widget _buildBarChart() {
    final dailyData = _dailyExpensesData;
    if (dailyData.isEmpty) {
      return const Center(
        child: Text(
          "Add expenses to see the chart",
          style: TextStyle(color: Colors.white70, fontFamily: 'Jost'),
        ),
      );
    }

    final dates = dailyData.keys.toList();
    final amounts = dailyData.values.toList();
    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);
    int adjustedStartIndex = dates.length - _visibleBars - _barChartStartIndex;
    if (adjustedStartIndex < 0) {
      adjustedStartIndex = 0;
    }

    final visibleDates = dates.sublist(adjustedStartIndex,
        (adjustedStartIndex + _visibleBars).clamp(0, dates.length));
    final visibleAmounts = amounts.sublist(adjustedStartIndex,
        (adjustedStartIndex + _visibleBars).clamp(0, amounts.length));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left, color: Colors.tealAccent),
                  onPressed: adjustedStartIndex > 0
                      ? () =>
                          setState(() => _barChartStartIndex += _visibleBars)
                      : null,
                ),
                const Text(
                  "Daily Expenses",
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Jost',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.tealAccent),
                  onPressed: adjustedStartIndex + _visibleBars < dates.length
                      ? () =>
                          setState(() => _barChartStartIndex -= _visibleBars)
                      : null,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount * 1.2,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.grey[800]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(2)}', // Changed '$' to '₹'
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Jost',
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < visibleDates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                visibleDates[index],
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 12,
                                  fontFamily: 'Jost',
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: expenseLimit.toDouble(),
                        getTitlesWidget: (value, meta) {
                          if (value == expenseLimit.toDouble()) {
                            return Text(
                              '₹${value.toInt()}', // Changed '$' to '₹'
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Jost',
                              ),
                            );
                          }
                          if (value % expenseLimit == 0) {
                            return Text(
                              '₹${value.toInt()}', // Changed '$' to '₹'
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'Jost',
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    horizontalInterval: expenseLimit.toDouble(),
                    getDrawingHorizontalLine: (value) {
                      if (value == expenseLimit) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        );
                      }
                      return FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  barGroups: List.generate(visibleAmounts.length, (index) {
                    final isOverLimit = visibleAmounts[index] > expenseLimit;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: visibleAmounts[index],
                          color: isOverLimit ? Colors.red : Colors.tealAccent,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        )
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    _nameController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    _errorText = null;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Text(
                "Add Expense",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Jost'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Expense Name",
                        labelStyle: TextStyle(
                            color: Colors.white70, fontFamily: 'Jost'),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                      ),
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Jost'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        labelStyle: const TextStyle(
                            color: Colors.white70, fontFamily: 'Jost'),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        errorText: _errorText,
                      ),
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Jost'),
                      onChanged: (value) {
                        setState(() {
                          _errorText =
                              (value.isEmpty || double.tryParse(value) == null)
                                  ? "Please enter a valid number"
                                  : null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Date: ${DateFormat.yMMMd().format(_selectedDate)}",
                            style: const TextStyle(
                                color: Colors.white70, fontFamily: 'Jost'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: Colors.tealAccent),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    textTheme: const TextTheme(
                                      bodyLarge: TextStyle(fontFamily: 'Jost'),
                                      bodyMedium: TextStyle(fontFamily: 'Jost'),
                                      bodySmall: TextStyle(fontFamily: 'Jost'),
                                      displayLarge:
                                          TextStyle(fontFamily: 'Jost'),
                                      displayMedium:
                                          TextStyle(fontFamily: 'Jost'),
                                      displaySmall:
                                          TextStyle(fontFamily: 'Jost'),
                                      headlineLarge:
                                          TextStyle(fontFamily: 'Jost'),
                                      headlineMedium:
                                          TextStyle(fontFamily: 'Jost'),
                                      headlineSmall:
                                          TextStyle(fontFamily: 'Jost'),
                                      labelLarge: TextStyle(fontFamily: 'Jost'),
                                      labelMedium:
                                          TextStyle(fontFamily: 'Jost'),
                                      labelSmall: TextStyle(fontFamily: 'Jost'),
                                      titleLarge: TextStyle(fontFamily: 'Jost'),
                                      titleMedium:
                                          TextStyle(fontFamily: 'Jost'),
                                      titleSmall: TextStyle(fontFamily: 'Jost'),
                                    ),
                                    colorScheme: ColorScheme.dark(
                                      primary: Colors.teal,
                                      onPrimary: Colors.black,
                                      surface: Colors.grey[900]!,
                                      onSurface: Colors.white,
                                    ),
                                    dialogTheme: const DialogThemeData(
                                      backgroundColor: Colors.black,
                                      titleTextStyle:
                                          TextStyle(fontFamily: 'Jost'),
                                      contentTextStyle:
                                          TextStyle(fontFamily: 'Jost'),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedDate != null) {
                              setState(() => _selectedDate = pickedDate);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel",
                      style: TextStyle(
                          color: Colors.redAccent, fontFamily: 'Jost')),
                ),
                TextButton(
                  onPressed: () {
                    if (_amountController.text.isEmpty ||
                        double.tryParse(_amountController.text) == null) {
                      setState(
                          () => _errorText = "Please enter a valid number");
                      return;
                    }

                    final newExpense = Expense(
                      name: _nameController.text,
                      amount: double.parse(_amountController.text),
                      date: _selectedDate,
                    );
                    Navigator.of(context).pop();
                    _addExpense(newExpense);
                  },
                  child: const Text("Add",
                      style: TextStyle(
                          color: Colors.tealAccent, fontFamily: 'Jost')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addExpense(Expense expense) {
    setState(() {
      expensesBox.add(expense);
    });
  }

  void _updateLimit(int newLimit) {
    setState(() {
      expenseLimit = newLimit;
    });
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
    });
  }

  void _deleteExpense(Expense expense) {
    setState(() {
      final index = expensesBox.values.toList().indexOf(expense);
      if (index != -1) {
        expensesBox.deleteAt(index);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${expense.name} removed',
              style: const TextStyle(fontFamily: 'Jost')),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedExpenses = _groupedExpenses;
    final dateKeys = groupedExpenses.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MoneyMate",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            fontFamily: 'Jost',
          ),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MoneyMate',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 24,
                  fontFamily: 'Jost',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading:
                    const Icon(Icons.attach_money, color: Colors.tealAccent),
                title: const Text('Set Expense Limit',
                    style: TextStyle(color: Colors.white, fontFamily: 'Jost')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SetLimitPage(
                        currentLimit: expenseLimit,
                        onLimitChanged: _updateLimit,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildBarChart(),
          Expanded(
            child: expensesBox.isEmpty
                ? const Center(
                    child: Text(
                      "No expenses added yet",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontFamily: 'Jost'),
                    ),
                  )
                : ListView.builder(
                    itemCount: dateKeys.length,
                    itemBuilder: (context, dateIndex) {
                      final date = dateKeys[dateIndex];
                      final expensesForDate = groupedExpenses[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              date,
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Jost',
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: expensesForDate.length,
                            itemBuilder: (context, expenseIndex) {
                              final expense = expensesForDate[expenseIndex];
                              return Dismissible(
                                key: Key(
                                    '${expense.name}_${expense.date.millisecondsSinceEpoch}'),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20.0),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  return direction ==
                                      DismissDirection.startToEnd;
                                },
                                onDismissed: (direction) {
                                  _deleteExpense(expense);
                                },
                                child: Card(
                                  color: _isDeleteMode
                                      ? Colors.grey[800]
                                      : Colors.grey[900],
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  child: ListTile(
                                    title: Text(expense.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Jost')),
                                    subtitle: Text(
                                      DateFormat.jm().format(expense.date),
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontFamily: 'Jost'),
                                    ),
                                    trailing: _isDeleteMode
                                        ? IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteExpense(expense),
                                          )
                                        : Text(
                                            "₹${expense.amount.toStringAsFixed(2)}", // Changed '$' to '₹'
                                            style: const TextStyle(
                                              color: Colors.tealAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              fontFamily: 'Jost',
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(left: _buttonHorizontalMargin),
              child: FloatingActionButton(
                heroTag: 'delete',
                onPressed: _toggleDeleteMode,
                backgroundColor: _isDeleteMode ? Colors.red : Colors.teal,
                child: Icon(
                  _isDeleteMode ? Icons.close : Icons.remove,
                  color: Colors.black,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: _buttonHorizontalMargin),
              child: FloatingActionButton(
                heroTag: 'add',
                onPressed: _showAddExpenseDialog,
                backgroundColor: Colors.teal,
                child: const Icon(Icons.add, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontFamily: 'Jost'),
        ),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.tealAccent),
            title: const Text('Set Expense Limit',
                style: TextStyle(color: Colors.white, fontFamily: 'Jost')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SetLimitPage(
                      currentLimit: 500, onLimitChanged: null),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SetLimitPage extends StatefulWidget {
  final int currentLimit;
  final ValueChanged<int>? onLimitChanged;
  const SetLimitPage({
    super.key,
    required this.currentLimit,
    required this.onLimitChanged,
  });
  @override
  State<SetLimitPage> createState() => _SetLimitPageState();
}

class _SetLimitPageState extends State<SetLimitPage> {
  final TextEditingController _limitController = TextEditingController();
  String? _errorText;
  @override
  void initState() {
    super.initState();
    _limitController.text = widget.currentLimit.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set Expense Limit',
          style: TextStyle(fontFamily: 'Jost'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Expense Limit',
                labelStyle:
                    const TextStyle(color: Colors.white70, fontFamily: 'Jost'),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
                errorText: _errorText,
              ),
              style: const TextStyle(color: Colors.white, fontFamily: 'Jost'),
              onChanged: (value) {
                setState(() {
                  _errorText = (value.isEmpty || int.tryParse(value) == null)
                      ? 'Please enter a valid number'
                      : null;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_limitController.text.isEmpty ||
                    int.tryParse(_limitController.text) == null) {
                  setState(() => _errorText = 'Please enter a valid number');
                  return;
                }

                final newLimit = int.parse(_limitController.text);
                if (widget.onLimitChanged != null) {
                  widget.onLimitChanged!(newLimit);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontFamily: 'Jost'),
              ),
              child: const Text('Save Limit'),
            ),
          ],
        ),
      ),
    );
  }
}
