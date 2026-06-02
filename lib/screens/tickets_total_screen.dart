import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketsTotalScreen extends StatefulWidget {
  const TicketsTotalScreen({super.key});

  @override
  State<TicketsTotalScreen> createState() => _TicketsTotalScreenState();
}

class _TicketsTotalScreenState extends State<TicketsTotalScreen> {
  String _userName = '';
  String _selectedFilter = 'Total';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    setState(() {
      _userName = name;
    });
  }
  // Datos mock de alta fidelidad y premium
  final List<Map<String, dynamic>> _mockTickets = [
    {
      'id': 'SSP-0248',
      'solicitante': 'JUAN CARLOS MARTÍNEZ RUIZ',
      'ur': 'DIRECCIÓN GENERAL DE INFRAESTRUCTURA',
      'tipo_equipo': 'PC ESCRITORIO',
      'descripcion':
          'EL EQUIPO ENCIENDE PERO SE QUEDA TRABADO EN LA PANTALLA DE CARGA DE WINDOWS. SE INTENTÓ REINICIAR EN MODO SEGURO PERO EL COMPORTAMIENTO PERSISTE.',
      'fecha': 'Hoy • 10:15 AM',
      'estado': 'Pendiente',
      'color_estado': const Color(0xFFD97706), // Amber oscuro
      'bg_estado': const Color(0xFFFEF3C7), // Amber muy claro
      'icono': Icons.desktop_windows_rounded,
    },
    {
      'id': 'SSP-0245',
      'solicitante': 'MARÍA ELENA GÓMEZ CASTRO',
      'ur': 'SUBDIRECCIÓN DE RECURSOS HUMANOS',
      'tipo_equipo': 'IMPRESORA',
      'descripcion':
          'LA IMPRESORA MARCA ATASCO DE PAPEL CONSTANTE EN LA BANDEJA 2, INCLUSO CUANDO NO TIENE HOJAS OBSTRUYENDO. URGENTE PARA EMISIÓN DE NÓMINA.',
      'fecha': 'Ayer • 04:30 PM',
      'estado': 'En Proceso',
      'color_estado': const Color(0xFF2563EB), // Azul SSP premium
      'bg_estado': const Color(0xFFDBEAFE), // Azul claro
      'icono': Icons.print_rounded,
    },
    {
      'id': 'SSP-0240',
      'solicitante': 'ALEJANDRO SANDOVAL TINOCO',
      'ur': 'CUARTEL VALLADOLID',
      'tipo_equipo': 'TELEFONO',
      'descripcion':
          'EL TELÉFONO DE LA EXTENSIÓN 1420 NO DA TONO DE MARCACIÓN Y SE ESCUCHA ESTÁTICA CONTINUA EN LA BOCINA AL LEVANTAR EL AURICULAR DE LA BASE.',
      'fecha': '30 May 2026 • 11:20 AM',
      'estado': 'Resuelto',
      'color_estado': const Color(0xFF059669), // Verde esmeralda oscuro
      'bg_estado': const Color(0xFFD1FAE5), // Verde esmeralda claro
      'icono': Icons.phone_in_talk_rounded,
    },
    {
      'id': 'SSP-0239',
      'solicitante': 'PATRICIA ORTIZ AGUILAR',
      'ur': 'UNIDAD DE ASUNTOS INTERNOS',
      'tipo_equipo': 'LAPTOP',
      'descripcion':
          'LA LAPTOP INSTITUCIONAL HP PROBOOK NO LOGRA ENLAZAR CON EL PUNTO DE ACCESO WIFI DEL PISO 2, MIENTRAS QUE POR CABLE DE RED FUNCIONA SIN PROBLEMA.',
      'fecha': '29 May 2026 • 09:05 AM',
      'estado': 'Pendiente',
      'color_estado': const Color(0xFFD97706),
      'bg_estado': const Color(0xFFFEF3C7),
      'icono': Icons.laptop_chromebook_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final totalCount = _mockTickets.length;
    final assignedCount = _mockTickets
        .where((t) => t['estado'] == 'En Proceso' || t['estado'] == 'Asignado')
        .length;
    final closedCount = _mockTickets
        .where((t) => t['estado'] == 'Resuelto' || t['estado'] == 'Cerrado')
        .length;

    final filteredTickets = _mockTickets.where((t) {
      if (_selectedFilter == 'Total') return true;
      if (_selectedFilter == 'Asignados') {
        return t['estado'] == 'En Proceso' || t['estado'] == 'Asignado';
      }
      if (_selectedFilter == 'Cerrados') {
        return t['estado'] == 'Resuelto' || t['estado'] == 'Cerrado';
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
                _userName.isNotEmpty ? 'Bienvenido $_userName' : 'Bienvenido',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5C),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2E5C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Total: ${_mockTickets.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Cuadro descriptivo del Subtítulo
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF0A2E5C),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Listado global de todos los tickets reportados',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Fila de Estadísticas / Contadores rápidos
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                totalCount.toString(),
                const Color(0xFF0A2E5C), // Navy SSP
                const Color(0xFF0A2E5C).withValues(alpha: 0.1),
                Icons.confirmation_number_rounded,
                isSelected: _selectedFilter == 'Total',
                onTap: () => setState(() => _selectedFilter = 'Total'),
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
                onTap: () => setState(() => _selectedFilter = 'Asignados'),
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
                onTap: () => setState(() => _selectedFilter = 'Cerrados'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Listado de Tarjetas
        Expanded(
          child: filteredTickets.isEmpty
              ? _buildNoResultsState()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredTickets.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final ticket = filteredTickets[index];
                    return _buildTicketCard(ticket);
                  },
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A2E5C,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ticket['id'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Acción de simulación de ver detalles
                        _showTicketDetailsDialog(context, ticket);
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text(
                        'CERRAR TICKET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A2E5C),
                        side: BorderSide(
                          color: const Color(0xFF0A2E5C).withValues(alpha: 0.3),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2E5C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ticket['id'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2E5C),
                        ),
                      ),
                    ),
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

  // Estado vacío para búsquedas sin resultados
  Widget _buildNoResultsState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 70,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin resultados coincidentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta buscar con otros términos o palabras clave.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
