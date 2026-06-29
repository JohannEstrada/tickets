import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/close_ticket_dialog.dart';
import '../widgets/ticket_details_dialog.dart';

class TicketsTotalScreen extends StatefulWidget {
  const TicketsTotalScreen({super.key});

  @override
  State<TicketsTotalScreen> createState() => _TicketsTotalScreenState();
}

class _TicketsTotalScreenState extends State<TicketsTotalScreen> {
  String _userName = '';
  String _selectedFilter = 'Total';
  bool _isAscending = false;

  // Variables para la paginación y conexión al API real
  List<Map<String, dynamic>> _tickets =
      []; // Los 10 tickets de la página actual
  List<Map<String, dynamic>> _allTicketsCache =
      []; // Caché por si el API no está paginada
  bool _isServerPaginated = false; // Indica si la API paginó correctamente
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalTickets = 0;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();



  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchTickets(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    setState(() {
      _userName = name;
    });
  }

  Future<void> _fetchTickets({
    required int page,
    bool forceFetch = false,
  }) async {
    setState(() {
      _isLoading = true;
    });

    // Si ya tenemos caché local de todos los tickets y la API NO está paginada,
    // paginamos en memoria directamente para ahorrar red y ser instantáneos
    if (!_isServerPaginated && _allTicketsCache.isNotEmpty && !forceFetch) {
      _paginateLocally(page);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Solicitamos page y limit=10
      final response = await http.get(
        Uri.parse(
          'http://tickets.sspmichoacanlocal.gob.mx/api/tickets/revisar?page=$page&limit=10&per_page=10',
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
        int lastPage = 1;
        int currentPage = 1;
        int total = 0;
        bool detectedServerPagination = false;

        if (decoded is Map) {
          if (decoded['current_page'] != null ||
              decoded['meta']?['current_page'] != null) {
            detectedServerPagination = true;
          }

          if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['tickets'] is List) {
            rawList = decoded['tickets'];
          } else if (decoded['data'] is Map &&
              decoded['data']['data'] is List) {
            rawList = decoded['data']['data'];
          }

          currentPage =
              decoded['current_page'] ??
              decoded['meta']?['current_page'] ??
              page;
          lastPage =
              decoded['last_page'] ?? decoded['meta']?['last_page'] ?? page;
          total =
              decoded['total'] ?? decoded['meta']?['total'] ?? rawList.length;
        } else if (decoded is List) {
          rawList = decoded;
          total = rawList.length;
        }

        // Filtrar por el id del usuario logueado (user_id)
        final int? loggedUserId = prefs.getInt('user_id');
        if (loggedUserId != null) {
          rawList = rawList.where((item) {
            final dynamic ticketUserId = item['user_id'];
            if (ticketUserId == null) return false;
            final int? parsedTicketUserId = ticketUserId is int
                ? ticketUserId
                : int.tryParse(ticketUserId.toString());
            return parsedTicketUserId == loggedUserId;
          }).toList();
          total = rawList.length;
        }

        final List<Map<String, dynamic>> parsedTickets = rawList.map((item) {
          final String nom = (item['nombre'] ?? '').toString().trim();
          final String pat = (item['ap_paterno'] ?? '').toString().trim();
          final String mat = (item['ap_materno'] ?? '').toString().trim();

          String solicitante = '';
          if (nom.isNotEmpty) solicitante += nom;
          if (pat.isNotEmpty)
            solicitante += (solicitante.isNotEmpty ? ' ' : '') + pat;
          if (mat.isNotEmpty)
            solicitante += (solicitante.isNotEmpty ? ' ' : '') + mat;
          if (solicitante.isEmpty) solicitante = 'SIN NOMBRE';

          final String rawDate = item['created_at'] ?? item['fecha'] ?? '';
          String fecha = 'Fecha no disponible';
          DateTime? rawDateTime;
          if (rawDate.isNotEmpty) {
            try {
              rawDateTime = DateTime.parse(rawDate);
              fecha =
                  '${rawDateTime.day.toString().padLeft(2, '0')}/${rawDateTime.month.toString().padLeft(2, '0')}/${rawDateTime.year} • ${rawDateTime.hour.toString().padLeft(2, '0')}:${rawDateTime.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              fecha = rawDate;
            }
          }

          String urNombre = 'Ubicación no especificada';
          if (item['ur'] != null) {
            if (item['ur'] is Map) {
              urNombre =
                  item['ur']['nombre'] ??
                  item['ur']['descripcion'] ??
                  'Ubicación';
            } else {
              urNombre = item['ur'].toString();
            }
          } else if (item['ur_nombre'] != null) {
            urNombre = item['ur_nombre'].toString();
          }

          final String rawEstado =
              (item['estado_actual'] ?? item['estado'] ?? '1')
                  .toString()
                  .trim()
                  .toUpperCase();
          String estado = 'Asignado';
          if (rawEstado == '5' || rawEstado == 'CERRADO') {
            estado = 'Cerrado';
          } else {
            estado = 'Asignado';
          }

          Color colorEstado = const Color(0xFF2563EB);
          Color bgEstado = const Color(0xFFDBEAFE);
          IconData icono = Icons.devices_other_rounded;

          if (estado == 'Cerrado') {
            colorEstado = const Color(0xFF059669);
            bgEstado = const Color(0xFFD1FAE5);
          }

          final String tipo = (item['tipo_equipo'] ?? '')
              .toString()
              .toUpperCase();
          if (tipo.contains('PC') || tipo.contains('ESCRITORIO')) {
            icono = Icons.desktop_windows_rounded;
          } else if (tipo.contains('IMPRESORA') || tipo.contains('PRINT')) {
            icono = Icons.print_rounded;
          } else if (tipo.contains('LAP')) {
            icono = Icons.laptop_chromebook_rounded;
          } else if (tipo.contains('TEL')) {
            icono = Icons.phone_in_talk_rounded;
          }

          return {
            'id': 'SSP-${(item['id'] ?? '').toString().padLeft(4, '0')}',
            'db_id': item['id'],
            'solicitante': solicitante.toUpperCase(),
            'ur': urNombre.toUpperCase(),
            'tipo_equipo': tipo.isNotEmpty ? tipo : 'OTRO',
            'descripcion': (item['descripcion'] ?? 'SIN DESCRIPCIÓN')
                .toString()
                .toUpperCase(),
            'fecha': fecha,
            'raw_date_time': rawDateTime,
            'estado': estado,
            'color_estado': colorEstado,
            'bg_estado': bgEstado,
            'icono': icono,
            'raw': item,
          };
        }).toList();

        _sortList(parsedTickets);

        if (detectedServerPagination && rawList.length <= 10 && lastPage > 1) {
          // El servidor soporta paginación
          setState(() {
            _tickets = parsedTickets;
            _currentPage = currentPage;
            _lastPage = lastPage;
            _totalTickets = total;
            _isServerPaginated = true;
            _isLoading = false;
          });
        } else {
          // Si el servidor NO paginó (devolvió todos los registros juntos)
          // realizamos paginación en memoria (10 en 10)
          _allTicketsCache = parsedTickets;
          _isServerPaginated = false;
          _paginateLocally(page);
        }

        _scrollToTop();
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

  void _sortList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final DateTime? dateA = a['raw_date_time'];
      final DateTime? dateB = b['raw_date_time'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return _isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  void _sortAndPaginate() {
    if (_isServerPaginated) {
      _sortList(_tickets);
    } else {
      _sortList(_allTicketsCache);
      _paginateLocally(_currentPage);
    }
  }

  List<Map<String, dynamic>> _getFilteredTickets() {
    return _allTicketsCache.where((t) {
      if (_selectedFilter == 'Total') return true;
      if (_selectedFilter == 'Asignados') {
        return t['estado'] == 'Asignado';
      }
      if (_selectedFilter == 'Cerrados') {
        return t['estado'] == 'Cerrado';
      }
      return true;
    }).toList();
  }

  void _paginateLocally(int page) {
    final filteredList = _getFilteredTickets();
    final total = filteredList.length;
    final lastPage = (total / 10).ceil();
    final int currentPage = page.clamp(1, lastPage == 0 ? 1 : lastPage);

    final int startIndex = (currentPage - 1) * 10;
    int endIndex = startIndex + 10;
    if (endIndex > total) endIndex = total;

    final List<Map<String, dynamic>> pageTickets = (startIndex < total)
        ? filteredList.sublist(startIndex, endIndex)
        : [];

    setState(() {
      _tickets = pageTickets;
      _currentPage = currentPage;
      _lastPage = lastPage == 0 ? 1 : lastPage;
      _totalTickets = _allTicketsCache.length;
      _isLoading = false;
    });

    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final countSource = _isServerPaginated ? _tickets : _allTicketsCache;
    final assignedCount = countSource
        .where((t) => t['estado'] == 'Asignado')
        .length;
    final closedCount = countSource
        .where((t) => t['estado'] == 'Cerrado')
        .length;

    final filteredTickets = _tickets.where((t) {
      if (_selectedFilter == 'Total') return true;
      if (_selectedFilter == 'Asignados') {
        return t['estado'] == 'Asignado';
      }
      if (_selectedFilter == 'Cerrados') {
        return t['estado'] == 'Cerrado';
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con Título y Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _userName.isNotEmpty ? ' $_userName' : 'Bienvenido',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5C),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Fila de Estadísticas / Contadores rápidos
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                _totalTickets.toString(),
                const Color(0xFF0A2E5C), // Navy SSP
                const Color(0xFF0A2E5C).withValues(alpha: 0.1),
                Icons.confirmation_number_rounded,
                isSelected: _selectedFilter == 'Total',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Total';
                  });
                  if (!_isServerPaginated) {
                    _paginateLocally(1);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Asignados',
                assignedCount.toString(),
                const Color(0xFF2563EB), // Azul SSP premium
                const Color(0xFFDBEAFE),
                Icons.assignment_ind_rounded,
                isSelected: _selectedFilter == 'Asignados',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Asignados';
                  });
                  if (!_isServerPaginated) {
                    _paginateLocally(1);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Cerrados',
                closedCount.toString(),
                const Color(0xFF059669), // Verde
                const Color(0xFFD1FAE5),
                Icons.task_alt_rounded,
                isSelected: _selectedFilter == 'Cerrados',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Cerrados';
                  });
                  if (!_isServerPaginated) {
                    _paginateLocally(1);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Filtro y Ordenamiento de Fecha
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAscending ? 'Orden: Más antiguos' : 'Orden: Más recientes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isAscending = !_isAscending;
                    _sortAndPaginate();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2E5C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0A2E5C).withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: const Color(0xFF0A2E5C),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAscending ? 'Más antiguos' : 'Más recientes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2E5C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Listado de Tarjetas
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0A2E5C)),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0A2E5C),
                  onRefresh: () => _fetchTickets(page: 1, forceFetch: true),
                  child: filteredTickets.isEmpty
                      ? _buildNoResultsState()
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: filteredTickets.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final ticket = filteredTickets[index];
                            return _buildTicketCard(ticket);
                          },
                        ),
                ),
        ),

        // Barra de Paginación Tradicional
        if (_lastPage > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón Anterior
                IconButton(
                  onPressed: _currentPage > 1 && !_isLoading
                      ? () => _fetchTickets(page: _currentPage - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  iconSize: 18,
                  color: const Color(0xFF0A2E5C),
                  disabledColor: Colors.grey.shade300,
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage > 1
                        ? const Color(0xFF0A2E5C).withValues(alpha: 0.05)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                // Indicador de Página
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    'Página $_currentPage de $_lastPage',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                    ),
                  ),
                ),
                // Botón Siguiente
                IconButton(
                  onPressed: _currentPage < _lastPage && !_isLoading
                      ? () => _fetchTickets(page: _currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  iconSize: 18,
                  color: const Color(0xFF0A2E5C),
                  disabledColor: Colors.grey.shade300,
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage < _lastPage
                        ? const Color(0xFF0A2E5C).withValues(alpha: 0.05)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Tarjeta de Estadística Individual
  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    Color bgColor,
    IconData icon, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade100,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 12 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta del Ticket
  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la Tarjeta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        ticket['fecha'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Badge del Estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ticket['bg_estado'],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      ticket['estado'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ticket['color_estado'],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cuerpo de la Tarjeta
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila de Solicitante y Tipo de Equipo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono representativo del equipo
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A2E5C,
                          ).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          ticket['icono'],
                          color: const Color(0xFF0A2E5C),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket['solicitante'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ticket['tipo_equipo'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Ubicación / UR con icono
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ticket['ur'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Divider sutil
                  Container(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 12),

                  // Descripción de la falla
                  const Text(
                    'DESCRIPCIÓN DE LA FALLA:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ticket['descripcion'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Footer con Botón de Acción
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ticket['estado'] == 'Asignado'
                        ? ElevatedButton.icon(
                            onPressed: () {
                              _showCloseTicketDialog(context, ticket);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'CERRAR TICKET',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2E5C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () {
                              _showTicketDetailsDialog(context, ticket);
                            },
                            icon: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'VER TICKET',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: BorderSide(
                                color: const Color(
                                  0xFF059669,
                                ).withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }





  // Diálogo para la acción de cerrar un ticket
  void _showCloseTicketDialog(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CloseTicketDialog(
          ticket: ticket,
          onSuccess: () {
            _fetchTickets(
              page: _currentPage,
              forceFetch: true,
            );
          },
        );
      },
    );
  }

  // Diálogo para mostrar la información extendida en alta resolución
  void _showTicketDetailsDialog(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TicketDetailsDialog(ticket: ticket);
      },
    );
  }

  // Estado vacío para búsquedas sin resultados o filtros sin tickets
  Widget _buildNoResultsState() {
    String title = 'Sin resultados coincidentes';
    String subtitle = 'Intenta buscar con otros términos o palabras clave.';
    IconData icon = Icons.search_off_rounded;

    if (_selectedFilter == 'Asignados') {
      title = 'No hay ningún ticket asignado por el momento';
      subtitle = 'No tienes reportes pendientes de atención en este momento.';
      icon = Icons.assignment_turned_in_rounded;
    } else if (_selectedFilter == 'Cerrados') {
      title = 'No hay ningún ticket cerrado por el momento';
      subtitle = 'No tienes reportes resueltos registrados en este momento.';
      icon = Icons.task_alt_rounded;
    } else if (_selectedFilter == 'Total') {
      title = 'No se encontraron tickets registrados';
      subtitle =
          'No hay ningún reporte registrado en el sistema por el momento.';
      icon = Icons.folder_open_rounded;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 70, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
