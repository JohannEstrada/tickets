import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = true;

  // Variables de métricas del mes actual
  int _monthlyTotal = 0;
  int _monthlyAssigned = 0;
  int _monthlyClosed = 0;
  double _monthlyEfficiency = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? '';
      final String? token = prefs.getString('auth_token');
      final int? loggedUserId = prefs.getInt('user_id');

      setState(() {
        _userName = name;
      });

      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
          'http://tickets.sspmichoacanlocal.gob.mx/api/tickets/revisar?limit=1000&per_page=1000',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];

        if (decoded is Map) {
          if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['tickets'] is List) {
            rawList = decoded['tickets'];
          } else if (decoded['data'] is Map &&
              decoded['data']['data'] is List) {
            rawList = decoded['data']['data'];
          }
        } else if (decoded is List) {
          rawList = decoded;
        }

        final now = DateTime.now();
        final currentMonth = now.month;
        final currentYear = now.year;

        // Filtrar por el id del usuario logueado (user_id) y mes actual
        if (loggedUserId != null) {
          rawList = rawList.where((item) {
            final dynamic ticketUserId = item['user_id'];
            if (ticketUserId == null) return false;
            final int? parsedTicketUserId = ticketUserId is int
                ? ticketUserId
                : int.tryParse(ticketUserId.toString());
            if (parsedTicketUserId != loggedUserId) return false;

            final String rawDate = (item['created_at'] ?? item['fecha'] ?? '')
                .toString();
            if (rawDate.isNotEmpty) {
              try {
                final parsedDate = DateTime.parse(rawDate);
                return parsedDate.month == currentMonth &&
                    parsedDate.year == currentYear;
              } catch (_) {
                return false;
              }
            }
            return false;
          }).toList();
        }

        int assignedCount = 0;
        int closedCount = 0;

        for (var item in rawList) {
          final String rawEstado =
              (item['estado_actual'] ?? item['estado'] ?? '1')
                  .toString()
                  .trim()
                  .toUpperCase();
          if (rawEstado == '5' || rawEstado == 'CERRADO') {
            closedCount++;
          } else {
            assignedCount++;
          }
        }

        setState(() {
          _monthlyTotal = rawList.length;
          _monthlyAssigned = assignedCount;
          _monthlyClosed = closedCount;
          _monthlyEfficiency = _monthlyTotal > 0
              ? (closedCount / _monthlyTotal) * 100.0
              : 0.0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getCurrentMonthName() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0A2E5C)),
      );
    }

    final String greetingName = _userName.isNotEmpty
        ? _userName.split(' ')[0]
        : 'Técnico';

    return RefreshIndicator(
      color: const Color(0xFF0A2E5C),
      onRefresh: () => _loadDashboardData(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Banner de Bienvenida Premium
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A2E5C), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A2E5C).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '¡Hola, $greetingName!, buenas tardes',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Bienvenido a tu panel de soporte técnico. Aquí puedes gestionar tus reportes del día.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade100,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Título de la sección del mes
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF0A2E5C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen de ${_getCurrentMonthName()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Tarjeta de Eficiencia Expandida (Opción A)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Eficiencia de Resolución',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rendimiento en el mes actual',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${_monthlyEfficiency.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _monthlyTotal > 0
                        ? (_monthlyClosed / _monthlyTotal)
                        : 0.0,
                    backgroundColor: const Color(
                      0xFF7C3AED,
                    ).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF7C3AED),
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_monthlyClosed resueltos de $_monthlyTotal en total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Tarjetas individuales de contadores
          _buildMetricCard(
            title: 'Total del Mes',
            subtitle: 'Todos tus soportes registrados',
            value: _monthlyTotal.toString(),
            icon: Icons.summarize_rounded,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: 'Tickets Asignados',
            subtitle: 'Soportes activos en proceso',
            value: _monthlyAssigned.toString(),
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: 'Tickets Resueltos',
            subtitle: 'Soportes finalizados con éxito',
            value: _monthlyClosed.toString(),
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
}
