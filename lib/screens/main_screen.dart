import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'tickets_total_screen.dart';
import 'tickets_assigned_screen.dart';
import 'tickets_closed_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _urs = [];
  bool _isLoadingURs = true;

  @override
  void initState() {
    super.initState();
    _fetchURs();
  }

  Future<void> _fetchURs() async {
    setState(() {
      _isLoadingURs = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _isLoadingURs = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://tickets.sspmichoacanlocal.gob.mx/api/urs/revisar'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          rawList = decoded['data'];
        } else if (decoded is Map && decoded['urs'] is List) {
          rawList = decoded['urs'];
        }

        setState(() {
          _urs = rawList.map((item) {
            return {
              'id': item['id'],
              'nombre':
                  item['nombre'] ??
                  item['descripcion'] ??
                  item['ur'] ??
                  'Ubicación ${item['id']}',
            };
          }).toList();
          _isLoadingURs = false;
        });
      } else {
        setState(() {
          _isLoadingURs = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoadingURs = false;
      });
    }
  }

  // Lista de pantallas que se mostrarán en el cuerpo
  final List<Widget> _screens = const [
    HomeScreen(),
    TicketsTotalScreen(),
    TicketsAssignedScreen(),
    TicketsClosedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Gris Slate muy claro de fondo
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera común y persistente
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TICKETS SSP',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2E5C),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Subdirección de Soporte Técnico e Informática',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showLogoutConfirmationDialog(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF0A2E5C),
                    ),
                    tooltip: 'Cerrar Sesión',
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Cuerpo de la pestaña activa usando IndexedStack para mantener el estado de cada una
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70, // Espacio premium idéntico
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _buildNavIcon(
                      Icons.home_rounded,
                      'Inicio',
                      _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _buildNavIcon(
                      Icons.confirmation_number_rounded,
                      'Total',
                      _currentIndex == 1,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                  ),
                ),
                Expanded(child: Center(child: _buildAddTicketButton(context))),
                Expanded(
                  child: Center(
                    child: _buildNavIcon(
                      Icons.assignment_ind_rounded,
                      'Asignados',
                      _currentIndex == 2,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _buildNavIcon(
                      Icons.task_alt_rounded,
                      'Cerrados',
                      _currentIndex == 3,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTicketButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateTicketModal(context),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0A2E5C),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2E5C).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  void _showCreateTicketModal(BuildContext context) {
    String? selectedDeviceType;
    String? selectedUR;
    final nameController = TextEditingController();
    final paternalController = TextEditingController();
    final maternalController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              context,
            ).viewInsets.bottom, // Ajuste para el teclado
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Nuevo Ticket de Soporte',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Describe el problema técnico para levantar un reporte.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Campo Nombre
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF1E293B)),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => TextEditingValue(
                          text: newValue.text.toUpperCase(),
                          selection: newValue.selection,
                        ),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0A2E5C),
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
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Campos de Apellidos (Fila horizontal para optimizar espacio y diseño)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: paternalController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => TextEditingValue(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Apellido Paterno',
                            labelStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_rounded,
                              color: Color(0xFF0A2E5C),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF0A2E5C),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maternalController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => TextEditingValue(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Apellido Materno',
                            labelStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF0A2E5C),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF0A2E5C),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Campo Descripción
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Color(0xFF1E293B)),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción de la falla',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(
                          Icons.description_outlined,
                          color: Color(0xFF0A2E5C),
                        ),
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
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Campo Tipo de Equipo (Dropdown)
                  DropdownButtonFormField<String>(
                    value: selectedDeviceType,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFF0A2E5C),
                      size: 28,
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tipo de equipo',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.devices_other_rounded,
                        color: Color(0xFF0A2E5C),
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
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PC ESCRITORIO',
                        child: Text('PC ESCRITORIO'),
                      ),
                      DropdownMenuItem(
                        value: 'IMPRESORA',
                        child: Text('IMPRESORA'),
                      ),
                      DropdownMenuItem(
                        value: 'MONITOR',
                        child: Text('MONITOR'),
                      ),
                      DropdownMenuItem(
                        value: 'TELEFONO',
                        child: Text('TELEFONO'),
                      ),
                      DropdownMenuItem(value: 'LAPTOP', child: Text('LAPTOP')),
                      DropdownMenuItem(value: 'OTRO', child: Text('OTRO')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        selectedDeviceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  // Campo Ubicación (UR)
                  DropdownButtonFormField<String>(
                    value: selectedUR,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFF0A2E5C),
                      size: 28,
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Ubicación (UR)',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF0A2E5C),
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
                    ),
                    items: _isLoadingURs
                        ? const [
                            DropdownMenuItem<String>(
                              value: null,
                              enabled: false,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0A2E5C),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Cargando ubicaciones...'),
                                ],
                              ),
                            ),
                          ]
                        : (_urs.isEmpty
                              ? const [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    enabled: false,
                                    child: Text('Error al cargar ubicaciones'),
                                  ),
                                ]
                              : _urs.map((ur) {
                                  return DropdownMenuItem<String>(
                                    value: ur['id'].toString(),
                                    child: Text(
                                      ur['nombre'].toString().toUpperCase(),
                                    ),
                                  );
                                }).toList()),
                    onChanged: (value) {
                      setModalState(() {
                        selectedUR = value;
                      });
                    },
                  ),
                  const SizedBox(height: 28),

                  // Botón de Enviar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              // Validación de campos
                              if (nameController.text.trim().isEmpty ||
                                  paternalController.text.trim().isEmpty ||
                                  maternalController.text.trim().isEmpty ||
                                  descriptionController.text.trim().isEmpty ||
                                  selectedDeviceType == null ||
                                  selectedUR == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Por favor, llena todos los campos',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                              });

                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final String? token = prefs.getString(
                                  'auth_token',
                                );

                                if (token == null) {
                                  setModalState(() {
                                    isSubmitting = false;
                                  });
                                  return;
                                }

                                // NOTA: Endpoint de creación de tickets
                                final String url =
                                    'http://tickets.sspmichoacanlocal.gob.mx/api/tickets/nuevo';
                                final Map<String, String> headers = {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                  'Authorization': 'Bearer $token',
                                };
                                final Map<String, dynamic> requestBody = {
                                  'nombre': nameController.text
                                      .trim()
                                      .toUpperCase(),
                                  'ap_paterno': paternalController.text
                                      .trim()
                                      .toUpperCase(),
                                  'ap_materno': maternalController.text
                                      .trim()
                                      .toUpperCase(),
                                  'descripcion': descriptionController.text
                                      .trim(),
                                  'tipo_equipo': selectedDeviceType,
                                  'ur_id':
                                      int.tryParse(selectedUR!) ?? selectedUR,
                                  'cuartel_id': 1,
                                  'modulo_origen': 3,
                                };

                                print(
                                  '========== INICIO DE PETICIÓN POST (CREAR TICKET) ==========',
                                );
                                print('URL: $url');
                                print('Headers: $headers');
                                print('Body: ${jsonEncode(requestBody)}');
                                print('--- DETALLE DE CAMPOS ---');
                                print('Nombre: ${requestBody['nombre']}');
                                print(
                                  'Ap Paterno: ${requestBody['ap_paterno']}',
                                );
                                print(
                                  'Ap Materno: ${requestBody['ap_materno']}',
                                );
                                print(
                                  'Descripción: ${requestBody['descripcion']}',
                                );
                                print(
                                  'Tipo Equipo: ${requestBody['tipo_equipo']}',
                                );
                                print('UR ID: ${requestBody['ur_id']}');
                                print('Cuartel: ${requestBody['cuartel_id']}');
                                print(
                                  'Módulo: ${requestBody['modulo_origen']}',
                                );
                                print(
                                  '===========================================================',
                                );

                                final response = await http.post(
                                  Uri.parse(url),
                                  headers: headers,
                                  body: jsonEncode(requestBody),
                                );

                                print(
                                  '========== RESPUESTA RECIBIDA DEL SERVIDOR ==========',
                                );
                                print('Status Code: ${response.statusCode}');
                                print('Headers: ${response.headers}');
                                print('Body: ${response.body}');
                                print(
                                  '======================================================',
                                );

                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(
                                          0xFF10B981,
                                        ), // Verde SSP Éxito
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Ticket registrado con éxito',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                  });

                                  String errMsg = 'Error al crear el ticket';
                                  try {
                                    final errData = jsonDecode(response.body);
                                    if (errData['message'] != null) {
                                      errMsg = errData['message'];
                                    }
                                  } catch (_) {}

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.redAccent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(child: Text(errMsg)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                print(
                                  '========== EXCEPCIÓN DETECTADA EN EL POST ==========',
                                );
                                print('Error: $e');
                                print(
                                  '====================================================',
                                );
                                setModalState(() {
                                  isSubmitting = false;
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      content: const Row(
                                        children: [
                                          Icon(
                                            Icons.wifi_off_rounded,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Fallo de conexión al enviar el reporte',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2E5C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CREAR TICKET',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono decorativo de logout con fondo sutil rojo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                // Título
                const Text(
                  '¿Cerrar Sesión?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Mensaje descriptivo
                Text(
                  '¿Estás seguro de que deseas salir? Tendrás que introducir tus credenciales nuevamente.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Botones de acción
                Row(
                  children: [
                    // Botón Cancelar (Outlined para menor peso visual)
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'CANCELAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón Confirmar (Elevated con fondo rojo)
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Cierra el diálogo
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'SALIR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavIcon(
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF0A2E5C) : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF0A2E5C) : Colors.grey,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
