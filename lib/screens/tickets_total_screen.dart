import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

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

  // Variables para la validación de credencial QR en cerrado de ticket
  bool _credencialValidada = false;
  bool _equipoValidado = false;
  String? _nombreConductorValidado;
  String? _vigenciaCredencial;
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _procedimientoController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchTickets(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scannerController.dispose();
    _procedimientoController.dispose();
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

  // Método auxiliar para mostrar alertas de tipo SnackBar
  void _mostrarMensaje(String mensaje, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _escanearQREquipo({VoidCallback? onUpdate}) async {
    final controller = _scannerController;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear QR de Equipo'),
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          final String rawValue = barcodes.first.rawValue!.trim();

                          controller.stop();
                          Navigator.of(context).pop();

                          setState(() {
                            _equipoValidado = true;
                          });
                          onUpdate?.call();
                          debugPrint('QR de equipo escaneado: $rawValue');
                        }
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF0A2E5C),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 50,
                                  color: Color(0xFF0A2E5C),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Alinee el QR aquí',
                                  style: TextStyle(
                                    color: Color(0xFF0A2E5C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escanearQRValidarCredencial({VoidCallback? onUpdate}) async {
    final controller = _scannerController;

    // Mostrar diálogo con cámara directamente
    await showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar pulsando fuera del cuadro
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9, // 90% del ancho
          height: MediaQuery.of(context).size.height * 0.7, // 70% de la altura
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear Credencial'),
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Cámara de escaneo
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          final String rawValue = barcodes.first.rawValue!
                              .trim();

                          // Detiene la cámara y cierra el modal
                          controller.stop();
                          Navigator.of(context).pop();

                          // Llama a la validación directa
                          _validarQRDirectamente(rawValue, onUpdate: onUpdate);
                        }
                      },
                    ),
                    // Overlay guía para centrar el QR
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(
                                  0xFF0A2E5C,
                                ), // Borde azul corporativo
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.qr_code_scanner,
                                  size: 50,
                                  color: Color(0xFF0A2E5C),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Alinee el QR aquí',
                                  style: TextStyle(
                                    color: Color(0xFF0A2E5C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validarQRDirectamente(
    String qrCompleto, {
    VoidCallback? onUpdate,
  }) async {
    print(' INICIO COMPLETO DE VALIDACIÓN QR');
    print(' QR completo recibido: "$qrCompleto"');

    // DETECTAR TIPO DE QR
    if (qrCompleto.startsWith('http://') || qrCompleto.startsWith('https://')) {
      // QR NUEVO: Es una URL - extraer ID y consultar API
      print(' TIPO DETECTADO: QR CON URL (FORMATO NUEVO)');

      final uri = Uri.tryParse(qrCompleto);
      final String? idExtraido = uri?.queryParameters['id'];

      if (idExtraido != null && idExtraido.isNotEmpty) {
        await _enviarDatosApi(idExtraido, onUpdate: onUpdate);
      } else {
        _mostrarMensaje(
          'No se encontró un ID válido en el código QR',
          color: Colors.red,
        );
      }
    } else if (qrCompleto.contains('NOMBRE:') &&
        qrCompleto.contains('VIGENCIA:')) {
      // QR ANTIGUO: Es texto plano - procesar localmente
      print('Tipo detectado: QR de texto plano (formato antiguo)');

      // Extraer vigencia del QR
      String? vigenciaExtraida;
      if (qrCompleto.contains('VIGENCIA:')) {
        final RegExp vigenciaRegex = RegExp(r'VIGENCIA:([^|]+)');
        final Match? match = vigenciaRegex.firstMatch(qrCompleto);
        if (match != null) {
          vigenciaExtraida = match.group(1)?.trim();
        }
      }

      // Extraer nombre del QR
      String? nombreExtraido;
      if (qrCompleto.contains('NOMBRE:')) {
        final RegExp nombreRegex = RegExp(r'NOMBRE:([^|]+)');
        final Match? match = nombreRegex.firstMatch(qrCompleto);
        if (match != null) {
          nombreExtraido = match.group(1)?.trim();
        }
      }

      // Validar que ambos datos fueron extraídos correctamente
      if (nombreExtraido == null || nombreExtraido.isEmpty) {
        _mostrarMensaje(
          'El QR no contiene información de nombre',
          color: Colors.red,
        );
        return;
      }

      if (vigenciaExtraida == null || vigenciaExtraida.isEmpty) {
        _mostrarMensaje(
          'El QR no contiene información de vigencia',
          color: Colors.red,
        );
        return;
      }

      // Parsear vigencia del formato de texto plano (Ej. "MARZO 2027")
      final RegExp mesAnoRegex = RegExp(r'([A-Z]+)\s+(\d{4})');
      final Match? match = mesAnoRegex.firstMatch(
        vigenciaExtraida.toUpperCase(),
      );

      if (match == null) {
        _mostrarMensaje('Formato de vigencia no reconocido', color: Colors.red);
        setState(() {
          _credencialValidada = false;
          _nombreConductorValidado = null;
          _vigenciaCredencial = null;
        });
        onUpdate?.call();
        return;
      }

      final String mes = match.group(1)!;
      final int ano = int.parse(match.group(2)!);

      final Map<String, int> meses = {
        'ENERO': 1,
        'FEBRERO': 2,
        'MARZO': 3,
        'ABRIL': 4,
        'MAYO': 5,
        'JUNIO': 6,
        'JULIO': 7,
        'AGOSTO': 8,
        'SEPTIEMBRE': 9,
        'OCTUBRE': 10,
        'NOVIEMBRE': 11,
        'DICIEMBRE': 12,
      };

      final int mesNumero = meses[mes] ?? 1;
      final DateTime fechaVigencia = DateTime(
        ano,
        mesNumero + 1,
        0,
      ); // Último día del mes obtenido
      final DateTime fechaActual = DateTime.now();

      // Verificar si está vencida
      if (fechaActual.isAfter(fechaVigencia)) {
        // CREDENCIAL VENCIDA
        setState(() {
          _credencialValidada = false;
          _nombreConductorValidado = null;
          _vigenciaCredencial = null;
        });
        onUpdate?.call();
        _mostrarDialogoCredencialVencida(vigenciaExtraida);
      } else {
        // CREDENCIAL VIGENTE
        setState(() {
          _credencialValidada = true;
          _nombreConductorValidado = nombreExtraido;
          _vigenciaCredencial = vigenciaExtraida;
        });
        onUpdate?.call();
        _mostrarMensaje(
          'CREDENCIAL VIGENTE\nPersonal atendido: $nombreExtraido',
          color: Colors.green,
        );
      }
    } else {
      _mostrarMensaje(
        'QR no válido o formato no reconocido',
        color: Colors.red,
      );
    }
  }

  Future<void> _enviarDatosApi(String id, {VoidCallback? onUpdate}) async {
    final url = Uri.parse(
      'http://187.216.141.163:8080/api_siarh/api_estatus_conductor.php',
    );
    _mostrarMensaje('Consultando credencial...', color: Colors.blue);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'action': 'get_conductor', 'id': id}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final Map<String, dynamic> conductorData = responseData['data'];

          // Extraer nombre completo
          final String nombreCompleto =
              '${conductorData['NOMBRE'] ?? ''} ${conductorData['PATERNO'] ?? ''} ${conductorData['MATERNO'] ?? ''}'
                  .trim();
          final String vigenciaCredencial = conductorData['VIGENCIA'] ?? 'N/A';

          // Validar vigencia por fecha (3 posibles formatos recibidos del servidor)
          bool fechaVigente = false;
          try {
            // MÉTODO 1: Intentar formato completo con día (DD/MES/YYYY) -> Ej. "31/MAR/2027"
            final RegExp fechaRegexCompleta = RegExp(
              r'(\d{1,2})/([A-Z]{3})/(\d{4})',
            );
            final Match? matchCompleto = fechaRegexCompleta.firstMatch(
              vigenciaCredencial,
            );

            final Map<String, int> mesesAbrev = {
              'ENE': 1,
              'FEB': 2,
              'MAR': 3,
              'ABR': 4,
              'MAY': 5,
              'JUN': 6,
              'JUL': 7,
              'AGO': 8,
              'SEP': 9,
              'OCT': 10,
              'NOV': 11,
              'DIC': 12,
            };

            if (matchCompleto != null) {
              final int dia = int.parse(matchCompleto.group(1)!);
              final String mesStr = matchCompleto.group(2)!;
              final int ano = int.parse(matchCompleto.group(3)!);

              final int mes = mesesAbrev[mesStr] ?? 1;
              final DateTime fechaVigencia = DateTime(
                ano,
                mes,
                dia,
                23,
                59,
                59,
              );
              fechaVigente = DateTime.now().isBefore(fechaVigencia);
            } else {
              // MÉTODO 2: Intentar formato sin día (MES/YYYY) -> Ej. "MAR/2027"
              final RegExp fechaRegexMes = RegExp(r'([A-Z]{3})/(\d{4})');
              final Match? matchMes = fechaRegexMes.firstMatch(
                vigenciaCredencial,
              );

              if (matchMes != null) {
                final String mesStr = matchMes.group(1)!;
                final int ano = int.parse(matchMes.group(2)!);

                final int mes = mesesAbrev[mesStr] ?? 1;
                final DateTime fechaVigencia = DateTime(
                  ano,
                  mes + 1,
                  0,
                  23,
                  59,
                  59,
                ); // Fin de mes
                fechaVigente = DateTime.now().isBefore(fechaVigencia);
              } else {
                // MÉTODO 3: Intentar formato con espacio (MES YYYY) -> Ej. "MAR 2027"
                final RegExp fechaRegexEspacio = RegExp(
                  r'([A-Z]{3})\s+(\d{4})',
                );
                final Match? matchEspacio = fechaRegexEspacio.firstMatch(
                  vigenciaCredencial,
                );

                if (matchEspacio != null) {
                  final String mesStr = matchEspacio.group(1)!;
                  final int ano = int.parse(matchEspacio.group(2)!);

                  final int mes = mesesAbrev[mesStr] ?? 1;
                  final DateTime fechaVigencia = DateTime(
                    ano,
                    mes + 1,
                    0,
                    23,
                    59,
                    59,
                  );
                  fechaVigente = DateTime.now().isBefore(fechaVigencia);
                }
              }
            }
          } catch (e) {
            print('🔥 Error parsing date: $e');
          }

          // Evaluar vigencia
          if (fechaVigente) {
            setState(() {
              _credencialValidada = true;
              _nombreConductorValidado = nombreCompleto;
              _vigenciaCredencial = vigenciaCredencial;
            });
            onUpdate?.call();

            _mostrarMensaje(
              'CREDENCIAL VIGENTE\nPersonal: $nombreCompleto',
              color: Colors.green,
            );
          } else {
            setState(() {
              _credencialValidada = false;
              _nombreConductorValidado = null;
              _vigenciaCredencial = null;
            });
            onUpdate?.call();
            _mostrarDialogoCredencialVencida(vigenciaCredencial);
          }
        } else {
          final String message =
              responseData['message'] ??
              'No se encontraron detalles para la credencial.';
          _mostrarMensaje('Error en la API: $message', color: Colors.red);
        }
      } else {
        _mostrarMensaje(
          'Error al consultar la credencial: ${response.statusCode}',
          color: Colors.red,
        );
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión al API: $e', color: Colors.red);
    }
  }

  void _mostrarDialogoCredencialVencida(String vigenciaExtraida) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obligatorio pulsar botón para cerrar
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Credencial Vencida',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No se puede regustrar el servicio técnico',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 8),
              Text(
                'La credencial está vencida\nVigencia: $vigenciaExtraida',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Regresar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Diálogo para la acción de cerrar un ticket
  void _showCloseTicketDialog(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    final String tipoEquipo = (ticket['tipo_equipo'] ?? '').toString().toUpperCase();
    final bool requiereEquipo = !tipoEquipo.contains('LAP') && !tipoEquipo.contains('OTRO');

    // Limpiar variables de validación de credencial QR al abrir el diálogo
    setState(() {
      _credencialValidada = false;
      _equipoValidado = !requiereEquipo;
      _nombreConductorValidado = null;
      _vigenciaCredencial = null;
    });
    _procedimientoController.clear();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 15,
              backgroundColor: Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cerrar Ticket',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DESCRIPCIÓN COMPLETA DE LA FALLA:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Text(
                        ticket['descripcion'] ?? 'Sin descripción disponible',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PROCEDIMIENTO HECHO:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _procedimientoController,
                      maxLines: 2,
                      minLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZÁÉÍÓÚÑáéíóúñ\s]'),
                        ),
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          ),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText:
                            'Escriba aquí los detalles del procedimiento realizado...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF0A2E5C),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    if (requiereEquipo) ...[
                      const SizedBox(height: 20),
                      // Campo de validación de equipo resguardado
                      const Text(
                        'VALIDACIÓN DE EQUIPO:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _equipoValidado
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _escanearQREquipo(
                              onUpdate: () => setStateDialog(() {}),
                            ),
                            icon: Icon(
                              _equipoValidado
                                  ? Icons.check_circle_rounded
                                  : Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              _equipoValidado
                                  ? 'Equipo Validado'
                                  : 'Escanear QR de Equipo',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _equipoValidado
                                  ? const Color(0xFF059669) // Verde elegante
                                  : const Color(0xFF0A2E5C), // Azul corporativo
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Campo de validación de credencial QR
                    const Text(
                      'VALIDACIÓN DE CREDENCIAL:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _credencialValidada
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _escanearQRValidarCredencial(
                            onUpdate: () => setStateDialog(() {}),
                          ),
                          icon: Icon(
                            _credencialValidada
                                ? Icons.check_circle_rounded
                                : Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _credencialValidada
                                ? 'Credencial Validada'
                                : 'Escanear QR para Validar',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credencialValidada
                                ? const Color(0xFF059669) // Verde elegante
                                : const Color(0xFF0A2E5C), // Azul corporativo
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_credencialValidada &&
                        _nombreConductorValidado != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PERSONAL VALIDADO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15803D),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _nombreConductorValidado!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF14532D),
                                    ),
                                  ),
                                  if (_vigenciaCredencial != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Vigencia: $_vigenciaCredencial',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_credencialValidada) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setStateDialog(() {
                                    isSubmitting = true;
                                  });

                                  final bool exitoPost =
                                      await _enviarRespuestaTicket(ticket);
                                  if (exitoPost) {
                                    final bool exitoPut =
                                        await _actualizarEstadoTicket(ticket);
                                    if (exitoPut && context.mounted) {
                                      Navigator.pop(context); // Cerrar diálogo
                                      _fetchTickets(
                                        page: _currentPage,
                                        forceFetch: true,
                                      ); // Refrescar lista
                                    }
                                  }

                                  setStateDialog(() {
                                    isSubmitting = false;
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF0A2E5C,
                            ), // Azul SSP
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'CERRAR TICKET',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Método para enviar la respuesta de cierre de ticket (POST)
  Future<bool> _enviarRespuestaTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) {
      _mostrarMensaje('Sesión no válida o expirada.', color: Colors.red);
      return false;
    }

    final url = Uri.parse(
      'http://tickets.sspmichoacanlocal.gob.mx/api/respuesta/nuevo',
    );

    final dynamic ticketId = ticket['db_id'] ?? ticket['id'];
    final dynamic userId = ticket['raw']?['user_id'] ?? ticket['user_id'];
    final String respuesta = _procedimientoController.text.trim().toUpperCase();

    if (respuesta.isEmpty) {
      _mostrarMensaje(
        'Por favor escriba el procedimiento realizado.',
        color: Colors.red,
      );
      return false;
    }

    final Map<String, dynamic> requestBody = {
      'respuesta': respuesta,
      'ticket_id': int.tryParse(ticketId.toString()) ?? ticketId,
      'user_id': int.tryParse(userId.toString()) ?? userId,
      'estado_id': 5,
    };

    debugPrint('-----------------------------------------');
    debugPrint('📤 ENVIANDO POST A: $url');
    debugPrint('🔑 Token: Bearer $token');
    debugPrint('📦 Body: ${jsonEncode(requestBody)}');
    debugPrint('-----------------------------------------');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 RESPUESTA POST - STATUS CODE: ${response.statusCode}');
      debugPrint('📥 RESPUESTA POST - BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarMensaje(
          'Procedimiento registrado con éxito.',
          color: Colors.green,
        );
        return true;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMsg =
            errorData['message'] ??
            'Error desconocido al guardar el procedimiento';
        _mostrarMensaje('Servidor: $errorMsg', color: Colors.red);
        return false;
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de red al registrar respuesta: $e',
        color: Colors.red,
      );
      return false;
    }
  }

  // Método para actualizar el estado del ticket a cerrado (PUT)
  Future<bool> _actualizarEstadoTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) {
      _mostrarMensaje('Sesión no válida o expirada.', color: Colors.red);
      return false;
    }

    final dynamic ticketId = ticket['db_id'] ?? ticket['id'];
    final url = Uri.parse(
      'http://tickets.sspmichoacanlocal.gob.mx/api/tickets/actualizar/$ticketId',
    );

    final Map<String, dynamic> requestBody = {'estado_actual': 5};

    debugPrint('-----------------------------------------');
    debugPrint('📤 ENVIANDO PUT A: $url');
    debugPrint('🔑 Token: Bearer $token');
    debugPrint('📦 Body: ${jsonEncode(requestBody)}');
    debugPrint('-----------------------------------------');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 RESPUESTA PUT - STATUS CODE: ${response.statusCode}');
      debugPrint('📥 RESPUESTA PUT - BODY: ${response.body}');

      if (response.statusCode == 200) {
        _mostrarMensaje('Ticket cerrado correctamente.', color: Colors.green);
        return true;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMsg =
            errorData['message'] ?? 'Error desconocido al actualizar el estado';
        _mostrarMensaje('Servidor: $errorMsg', color: Colors.red);
        return false;
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de red al actualizar estado: $e',
        color: Colors.red,
      );
      return false;
    }
  }

  // Diálogo para mostrar la información extendida en alta resolución
  void _showTicketDetailsDialog(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 15,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior de detalles rápidos
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Solicitante
                const Text(
                  'SOLICITANTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ticket['solicitante'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),

                // UR / Ubicación
                const Text(
                  'UBICACIÓN (UR)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ticket['ur'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),

                // Fila Tipo Equipo y Estado
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TIPO DE EQUIPO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ticket['tipo_equipo'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A2E5C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTADO ACTUAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ticket['bg_estado'],
                              borderRadius: BorderRadius.circular(20),
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
                  ],
                ),
                const SizedBox(height: 20),

                // Descripción completa de la falla
                const Text(
                  'DESCRIPCIÓN COMPLETA DE LA FALLA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    ticket['descripcion'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Aceptar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ENTENDIDO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
