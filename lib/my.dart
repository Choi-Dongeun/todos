import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
import 'todo.dart';
import 'nut.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyPage extends StatelessWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions;

  MyPage({required this.todos, required this.nutritions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Page')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('통계', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 20),
              _buildTodoCompletionChart(),
              SizedBox(height: 20),
              _buildNutritionIntakeChart(),
              SizedBox(height: 20),
              _buildCorrelationAnalysis(),
              SizedBox(height: 20),
              _buildRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoCompletionChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('todos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final todos = snapshot.data!.docs.map((doc) => Todo.fromFirestore(doc)).toList();
        final completionRates = _calculateTodoCompletionRates(todos);

        if (completionRates.isEmpty) {
          return Center(child: Text('할 일 데이터가 없습니다.'));
        }

        final now = DateTime.now();

        return Container(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false, // 전체 그리드 선을 숨김
                drawHorizontalLine: false, // 가로 점선 숨김
                drawVerticalLine: false,),   // 세로 점선 숨김
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      if (value == 120) return SizedBox(); // maxY에 해당하는 레이블 숨김
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      if (dayIndex < 0 || dayIndex > 6) return SizedBox();
                      final date = now.subtract(Duration(days: 6 - dayIndex));
                      return Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // 오른쪽 레이블 숨김
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // 위쪽 레이블 숨김
                ),
              ),
              borderData: FlBorderData(show: true),
              minX: 0, // X축 최소값
              maxX: 7, // X축 최대값
              minY: 0, // Y축 최소값
              maxY: 120, // Y축 최대값
              lineBarsData: [
                LineChartBarData(
                  spots: completionRates.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                  }).toList(),
                  isCurved: true, // 곡선을 유지
                  color: Colors.blue,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false), // 그래프 아래 영역 숨김
                ),
              ],
            ),
          ),
        );
      },
    );
  }




  Widget _buildNutritionIntakeChart() {
    final intakeRates = _calculateNutritionIntakeRates();
    return Container(
      height: 200,
      child: intakeRates.isEmpty
          ? Center(child: Text('영양제 데이터가 없습니다.'))
          : BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: intakeRates.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [BarChartRodData(toY: entry.value, color: Colors.green)],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorrelationAnalysis() {
    List<double> todoCompletionRates = _calculateTodoCompletionRates(todos);
    List<double> nutritionIntakeRates = _calculateNutritionIntakeRates();

    if (todoCompletionRates.isEmpty || nutritionIntakeRates.isEmpty) {
      return Text('상관관계를 계산할 데이터가 충분하지 않습니다.');
    }

    double correlation = _calculateCorrelation(todoCompletionRates, nutritionIntakeRates);
    return Text('할 일 완료율과 영양제 섭취율의 상관계수: ${correlation.toStringAsFixed(2)}');
  }

  Widget _buildRecommendations() {
    if (_calculateTodoCompletionRates(todos).isEmpty && _calculateNutritionIntakeRates().isEmpty) {
      return Text('추천을 생성할 데이터가 충분하지 않습니다.');
    }
    String recommendation = _generateRecommendation();
    return Text('추천: $recommendation', style: TextStyle(fontWeight: FontWeight.bold));
  }

  List<double> _calculateTodoCompletionRates(List<Todo> todos) {
    final now = DateTime.now(); //현재 날짜 기준
    return List.generate(7, (index) { //7일간의 데이터
      final date = now.subtract(Duration(days: index));
      final todosForDay = todos.where((todo) => isSameDay(todo.date, date)).toList(); //todosForDay에 저장
      if (todosForDay.isEmpty) return 0.0;
      final completedTodos = todosForDay.where((todo) => todo.isDone).length; //완료된 할 일 개수 계산
      return (completedTodos / todosForDay.length) * 100; //백분율
    }).reversed.toList();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<double> _calculateNutritionIntakeRates() {
    // 최근 7일간의 영양제 섭취율 계산
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      final nutritionsForDay = nutritions.where((nutrition) => isSameDay(nutrition.date, date)).toList();
      if (nutritionsForDay.isEmpty) return 0.0;
      final takenNutritions = nutritionsForDay.where((nutrition) => nutrition.taken).length;
      return (takenNutritions / nutritionsForDay.length) * 100;
    }).reversed.toList();
  }

  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    double sum_x = 0, sum_y = 0, sum_xy = 0;
    double squareSum_x = 0, squareSum_y = 0;

    for (int i = 0; i < x.length; i++) {
      sum_x += x[i];
      sum_y += y[i];
      sum_xy += x[i] * y[i];
      squareSum_x += x[i] * x[i];
      squareSum_y += y[i] * y[i];
    }

    double corr = (x.length * sum_xy - sum_x * sum_y) /
        (math.sqrt((x.length * squareSum_x - sum_x * sum_x) *
            (x.length * squareSum_y - sum_y * sum_y)));

    return corr;
  }

  String _generateRecommendation() {
    double todoAverage = _calculateTodoCompletionRates(todos).average;
    double nutritionAverage = _calculateNutritionIntakeRates().average;

    if (todoAverage < 50 && nutritionAverage < 50) {
      return '할 일 완료율과 영양제 섭취율을 모두 높이는 것이 좋겠습니다.';
    } else if (todoAverage < 50) {
      return '할 일 완료율을 높이면 전반적인 생산성이 향상될 수 있습니다.';
    } else if (nutritionAverage < 50) {
      return '영양제 섭취율을 높이면 건강 관리에 도움이 될 수 있습니다.';
    } else {
      return '현재 할 일 관리와 영양제 섭취가 잘 되고 있습니다. 계속 유지하세요!';
    }
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
